import 'dart:convert';

import 'package:flutter/services.dart';

import '../base_tool.dart';

class ProtocolLookupTool extends BaseTool {
  ProtocolLookupTool();

  List<Map<String, dynamic>>? _protocolCache;

  @override
  String get name => 'protocol_lookup';

  @override
  String get description =>
      'Use this to show a step-by-step medical protocol or checklist.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'topic': {'type': 'string'},
        },
        'required': ['topic'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final topic = arguments['topic']?.toString().trim() ?? '';
    if (topic.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'Missing protocol topic.',
        isError: true,
      );
    }

    final protocols = await _loadProtocols();
    final selected = _matchProtocol(protocols, topic);

    if (selected == null) {
      return ToolResult(
        toolName: name,
        output: 'No offline protocol found for "$topic".',
        isError: true,
      );
    }

    final html = _renderProtocolHtml(selected);
    return ToolResult(
      toolName: name,
      output: 'Rendered protocol for ${selected['title']}.',
      uiComponentType: 'html',
      uiData: {'html': html},
    );
  }

  Future<List<Map<String, dynamic>>> _loadProtocols() async {
    if (_protocolCache != null) {
      return _protocolCache!;
    }

    final raw = await rootBundle.loadString('assets/protocols.json');
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      _protocolCache = [];
      return _protocolCache!;
    }

    _protocolCache = decoded
        .whereType<Map<String, dynamic>>()
        .map((item) => item)
        .toList();
    return _protocolCache!;
  }

  Map<String, dynamic>? _matchProtocol(
    List<Map<String, dynamic>> protocols,
    String topic,
  ) {
    final normalized = topic.toLowerCase();

    for (final protocol in protocols) {
      final title = protocol['title']?.toString().toLowerCase() ?? '';
      if (title.contains(normalized)) {
        return protocol;
      }
    }

    for (final protocol in protocols) {
      final keywords = protocol['keywords'];
      if (keywords is List) {
        for (final keyword in keywords) {
          if (keyword.toString().toLowerCase().contains(normalized)) {
            return protocol;
          }
        }
      }
    }

    return null;
  }

  String _renderProtocolHtml(Map<String, dynamic> protocol) {
    final title = protocol['title'] ?? 'Protocol';
    final steps = (protocol['steps'] as List?)?.cast<String>() ?? const [];
    final warnings = (protocol['warnings'] as List?)?.cast<String>() ?? const [];
    final escalation =
        (protocol['seekHelp'] as List?)?.cast<String>() ?? const [];

    final stepHtml = steps
        .asMap()
        .entries
        .map((entry) =>
            '<li><strong>Step ${entry.key + 1}:</strong> ${entry.value}</li>')
        .join();

    final warningHtml = warnings
        .map((warning) => '<li>$warning</li>')
        .join();

    final escalationHtml = escalation
        .map((item) => '<li>$item</li>')
        .join();

    return '''
<div style="font-family: Georgia, serif;">
  <div style="padding:16px;border-radius:18px;background:#ffffff;border:1px solid #e6e1d8;">
    <h2 style="margin:0 0 8px 0;color:#1f1f1f;">$title</h2>
    <p style="margin:0 0 12px 0;color:#5c554c;">Offline quick protocol</p>
    <ol style="margin:0 0 16px 16px;padding:0;color:#1f1f1f;">$stepHtml</ol>
    <div style="padding:12px;border-radius:12px;background:#f7efe6;margin-bottom:12px;">
      <strong>Watch for</strong>
      <ul style="margin:8px 0 0 16px;padding:0;color:#534a40;">$warningHtml</ul>
    </div>
    <div style="padding:12px;border-radius:12px;background:#f1f1f1;">
      <strong>Seek help if</strong>
      <ul style="margin:8px 0 0 16px;padding:0;color:#534a40;">$escalationHtml</ul>
    </div>
  </div>
</div>
''';
  }
}
