import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';

import 'agent_events.dart';
import 'agent_tools.dart';

class LocalAgentFramework {
  static const _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  static const _systemInstructions = '''
You are an on-device Android assistant execution engine.
You must help the user by selecting the correct tool from the available tools listed below.
Always respond using a single valid JSON object. Do not wrap it in markdown block tags like ```json.

Available Tools:
1. "calculate_multiplication"
   Description: Use this only when the user explicitly asks to multiply two numbers.
   Arguments: {"num1": number, "num2": number}

2. "get_battery_status"
   Description: Use this when the user asks about the device battery or power level.
   Arguments: {}

If no tool matches the request, respond with this JSON format instead:
{"tool": "none", "reply": "Your conversational answer here"}
''';

  static const _finalResponseInstructions = '''
You are an on-device Android assistant.
A tool was executed for the user. Use the tool result and respond conversationally.
Do not output JSON. Provide a helpful final response.
''';

  final AgentTools _tools = AgentTools();

  bool _ready = false;
  dynamic _model;

  Future<void> initialize() async {
    if (_ready) {
      return;
    }

    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
      fileType: ModelFileType.litertlm,
    ).fromNetwork(_modelUrl).install();

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

    final execution = await _tools.execute(decision.tool, decision.arguments);
    if (execution.output.isNotEmpty) {
      yield AgentEvent(type: AgentEventType.toolResult, data: execution.output);
    }

    if (execution.output.startsWith('⚠️')) {
      yield AgentEvent(type: AgentEventType.responseToken, data: execution.output);
      return;
    }

    await for (final chunk in _getFinalResponse(
      userPrompt,
      toolResult: execution.output,
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
      Message(text: _systemInstructions, isUser: false),
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
    try {
      final parsed = jsonDecode(rawJson);
      if (parsed is! Map<String, dynamic>) {
        return _AgentDecision.none(
          reply: 'Framework error: tool response was not a JSON object.',
        );
      }

      final tool = parsed['tool']?.toString() ?? 'none';
      final reply = parsed['reply']?.toString() ?? '';
      final arguments = parsed['arguments'];

      return _AgentDecision(
        tool: tool,
        reply: reply,
        arguments: arguments is Map<String, dynamic> ? arguments : <String, dynamic>{},
      );
    } catch (error) {
      return _AgentDecision.none(
        reply:
            'Framework error: Gemma output failed validation. Raw: $rawJson',
      );
    }
  }

  Future<void> dispose() async {
    _ready = false;
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
