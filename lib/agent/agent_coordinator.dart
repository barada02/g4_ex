import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:isar_community/isar.dart';

import 'agent_events.dart';
import '../data/isar_database.dart';
import '../data/inventory_item.dart';
import '../data/incident_log.dart';
import 'base_tool.dart';
import 'tool_registry.dart';
import 'tools/incident_log_tool.dart';
import 'tools/incident_search_tool.dart';
import 'tools/html_render_tool.dart';
import 'tools/inventory_add_tool.dart';
import 'tools/inventory_low_stock_tool.dart';
import 'tools/inventory_search_tool.dart';
import 'tools/inventory_update_tool.dart';
import 'tools/protocol_lookup_tool.dart';

class AgentCoordinator {
  static const _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  static const _finalResponseInstructions = '''
You are Aegis, an offline emergency medical support assistant.
A tool was executed for the user. Use the tool result and respond conversationally.
Do not output JSON. Provide clear, calm guidance and next steps.
Add a short safety reminder when discussing medical care.
''';

  final ToolRegistry _registry = ToolRegistry();
  final IsarDatabase _database = IsarDatabase();

  bool _ready = false;
  dynamic _model;

  IsarDatabase get database => _database;
  Isar get isar => _database.instance;
  bool get isReady => _ready;

  AgentCoordinator() {
    _registry.registerTool(InventoryAddTool(_database));
    _registry.registerTool(InventoryUpdateTool(_database));
    _registry.registerTool(InventorySearchTool(_database));
    _registry.registerTool(InventoryLowStockTool(_database));
    _registry.registerTool(IncidentLogTool(_database));
    _registry.registerTool(IncidentSearchTool(_database));
    _registry.registerTool(ProtocolLookupTool());
    _registry.registerTool(HtmlRenderTool());
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
    await _seedDemoData();

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
        data: '⚠️ Aegis Agent called an unknown tool: "${decision.tool}"',
      );
      return;
    }

    // Capture visual context and tool execution safely with visual error reporting
    ToolResult result;
    try {
      final Map<String, dynamic> toolArguments = {
        ...?decision.arguments,
        if (imageBytes != null) 'imageBytes': imageBytes,
      };
      result = await tool.execute(toolArguments);
    } catch (e) {
      result = ToolResult(
        toolName: tool.name,
        output: '⚠️ Database/Schema Error: ${tool.name} failed to process. Details: $e',
        isError: true,
      );
    }

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
      yield AgentEvent(
        type: AgentEventType.responseToken,
        data: '\n\n🚨 **Tool Failure Diagnostic Alert**\n> ${result.output}\n',
      );
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
      var candidate = rawJson;
      // Strip off markdown wraps cleanly
      final startBlock = candidate.indexOf('```json');
      if (startBlock != -1) {
        final endBlock = candidate.indexOf('```', startBlock + 7);
        if (endBlock != -1) {
          candidate = candidate.substring(startBlock + 7, endBlock).trim();
        }
      } else {
        final startBlockGeneric = candidate.indexOf('```');
        if (startBlockGeneric != -1) {
          final endBlockGeneric = candidate.indexOf('```', startBlockGeneric + 3);
          if (endBlockGeneric != -1) {
            candidate = candidate.substring(startBlockGeneric + 3, endBlockGeneric).trim();
          }
        }
      }

      try {
        return jsonDecode(candidate);
      } catch (_) {
        final start = candidate.indexOf('{');
        final end = candidate.lastIndexOf('}');
        if (start == -1 || end == -1 || end <= start) {
          return null;
        }
        final finalCandidate = candidate.substring(start, end + 1);
        try {
          return jsonDecode(finalCandidate);
        } catch (_) {
          return null;
        }
      }
    }
  }

  Future<void> dispose() async {
    _ready = false;
    await _database.close();
  }

  Future<void> _seedDemoData() async {
    final isar = _database.instance;
    final count = await isar.inventoryItems.count();
    if (count > 0) {
      return;
    }

    final demoInventory = [
      InventoryItem()
        ..name = 'Bandage Roll'
        ..quantity = 18.0
        ..unit = 'rolls'
        ..location = 'Clinic Box A'
        ..expiryDate = DateTime.tryParse('2026-09-01')
        ..notes = 'Sterile gauze bandage rolls.'
        ..updatedAt = DateTime.now(),
      InventoryItem()
        ..name = 'Antiseptic Wipes'
        ..quantity = 42.0
        ..unit = 'packs'
        ..location = 'Clinic Box B'
        ..expiryDate = DateTime.tryParse('2027-01-15')
        ..notes = 'Convenient sterile sanitizing wipes.'
        ..updatedAt = DateTime.now(),
      InventoryItem()
        ..name = 'Pain Relief Tablets'
        ..quantity = 60.0
        ..unit = 'tablets'
        ..location = 'Clinic Box C'
        ..expiryDate = DateTime.tryParse('2026-12-31')
        ..notes = 'Adult dosage only.'
        ..updatedAt = DateTime.now(),
    ];

    final demoIncidents = [
      IncidentLog()
        ..title = 'Sprained Ankle'
        ..description = 'Swelling after evacuation walk, pain on weight bearing.'
        ..severity = 'medium'
        ..symptoms = 'Swelling, tenderness'
        ..actionTaken = 'Rest, cold pack, compression wrap.'
        ..createdAt = DateTime.now(),
      IncidentLog()
        ..title = 'Minor Burn'
        ..description = 'Contact with hot pan, redness and mild blistering.'
        ..severity = 'low'
        ..symptoms = 'Redness, warmth'
        ..actionTaken = 'Cooled with clean water, covered with clean dressing.'
        ..createdAt = DateTime.now(),
    ];

    await isar.writeTxn(() async {
      await isar.inventoryItems.putAll(demoInventory);
      await isar.incidentLogs.putAll(demoIncidents);
    });
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
