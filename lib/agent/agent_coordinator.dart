import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';

import 'agent_events.dart';
import '../data/isar_database.dart';
import 'base_tool.dart';
import 'tool_registry.dart';
import 'tools/battery_status_tool.dart';
import 'tools/multiplication_tool.dart';
import 'tools/note_clear_tool.dart';
import 'tools/note_insert_tool.dart';
import 'tools/note_search_tool.dart';
import 'tools/notes_dashboard_tool.dart';

class AgentCoordinator {
  static const _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  static const _finalResponseInstructions = '''
You are an on-device Android assistant.
A tool was executed for the user. Use the tool result and respond conversationally.
Do not output JSON. Provide a helpful final response.
''';

  final ToolRegistry _registry = ToolRegistry();
  final IsarDatabase _database = IsarDatabase();

  bool _ready = false;
  dynamic _model;

  AgentCoordinator() {
    _registry.registerTool(MultiplicationTool());
    _registry.registerTool(BatteryStatusTool());
    _registry.registerTool(NoteInsertTool(_database));
    _registry.registerTool(NoteSearchTool(_database));
    _registry.registerTool(NoteClearTool(_database));
    _registry.registerTool(NotesDashboardTool(_database));
  }

  void registerTool(BaseTool tool) {
    _registry.registerTool(tool);
  }

  void unregisterTool(String name) {
    _registry.unregisterTool(name);
  }

  Future<void> initialize() async {
    if (_ready) {
      return;
    }

    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(_modelUrl).install();

    await _database.initialize();

    _model = await FlutterGemma.getActiveModel(
      maxTokens: 4096,
      preferredBackend: PreferredBackend.gpu,
      supportImage: true,
      supportAudio: false,
    );

    _ready = true;
  }

  Stream<AgentEvent> runAgentCycle(
    String userPrompt, {
    Uint8List? imageBytes,
  }) async* {
    if (!_ready) {
      await initialize();
    }

    final decision = await _getToolDecision(
      userPrompt,
      imageBytes: imageBytes,
    );

    if (decision.tool == 'none') {
      yield AgentEvent(
        type: AgentEventType.responseToken,
        data: decision.reply.isEmpty
            ? 'No response generated.'
            : decision.reply,
      );
      return;
    }

    final tool = _registry.findTool(decision.tool);
    if (tool == null) {
      yield AgentEvent(
        type: AgentEventType.responseToken,
        data: '⚠️ Agent called an unknown tool: "${decision.tool}"',
      );
      return;
    }

    final result = await tool.execute(decision.arguments);
    if (result.uiComponentType != null && result.uiData != null) {
      yield AgentEvent(
        type: AgentEventType.uiRender,
        data: result.output,
        uiComponentType: result.uiComponentType,
        uiData: result.uiData,
      );
    } else if (result.output.isNotEmpty) {
      yield AgentEvent(type: AgentEventType.toolResult, data: result.output);
    }

    if (result.isError) {
      yield AgentEvent(type: AgentEventType.responseToken, data: result.output);
      return;
    }

    await for (final chunk in _getFinalResponse(
      userPrompt,
      toolResult: result.output,
      imageBytes: imageBytes,
    )) {
      yield AgentEvent(type: AgentEventType.responseToken, data: chunk);
    }
  }

  Future<_AgentDecision> _getToolDecision(
    String userPrompt, {
    Uint8List? imageBytes,
  }) async {
    final session = await _model.createSession(temperature: 0.0);

    await session.addQueryChunk(
      Message(text: _registry.buildSystemPrompt(), isUser: false),
    );
    await session.addQueryChunk(
      Message(
        text: userPrompt,
        images: imageBytes == null ? <Uint8List>[] : [imageBytes],
        isUser: true,
      ),
    );

    final buffer = StringBuffer();
    await for (final chunk in session.getResponseAsync()) {
      buffer.write(chunk);
    }
    await session.close();

    return _parseDecision(buffer.toString().trim());
  }

  Stream<String> _getFinalResponse(
    String userPrompt, {
    required String toolResult,
    Uint8List? imageBytes,
  }) async* {
    final session = await _model.createSession(temperature: 0.2);

    await session.addQueryChunk(
      Message(text: _finalResponseInstructions, isUser: false),
    );
    await session.addQueryChunk(
      Message(
        text: userPrompt,
        images: imageBytes == null ? <Uint8List>[] : [imageBytes],
        isUser: true,
      ),
    );
    await session.addQueryChunk(
      Message(text: 'Tool result: $toolResult', isUser: false),
    );

    await for (final chunk in session.getResponseAsync()) {
      yield chunk.toString();
    }
    await session.close();
  }

  _AgentDecision _parseDecision(String rawJson) {
    final decoded = _tryDecodeJson(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return _AgentDecision.none(
        reply: 'Framework error: tool response was not a JSON object.',
      );
    }

    final tool = decoded['tool']?.toString() ?? 'none';
    final reply = decoded['reply']?.toString() ?? '';
    final arguments = decoded['arguments'];

    return _AgentDecision(
      tool: tool,
      reply: reply,
      arguments: arguments is Map<String, dynamic> ? arguments : <String, dynamic>{},
    );
  }

  dynamic _tryDecodeJson(String rawJson) {
    try {
      return jsonDecode(rawJson);
    } catch (_) {
      final start = rawJson.indexOf('{');
      final end = rawJson.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) {
        return null;
      }
      final candidate = rawJson.substring(start, end + 1);
      try {
        return jsonDecode(candidate);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> dispose() async {
    _ready = false;
    await _database.close();
  }
}

class _AgentDecision {
  _AgentDecision({
    required this.tool,
    required this.reply,
    required this.arguments,
  });

  factory _AgentDecision.none({required String reply}) {
    return _AgentDecision(tool: 'none', reply: reply, arguments: {});
  }

  final String tool;
  final String reply;
  final Map<String, dynamic> arguments;
}
