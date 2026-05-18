import 'dart:convert';

import 'base_tool.dart';

class ToolRegistry {
  final List<BaseTool> _tools = [];

  void registerTool(BaseTool tool) {
    _tools.removeWhere((existing) => existing.name == tool.name);
    _tools.add(tool);
  }

  void unregisterTool(String name) {
    _tools.removeWhere((tool) => tool.name == name);
  }

  BaseTool? findTool(String name) {
    for (final tool in _tools) {
      if (tool.name == name) {
        return tool;
      }
    }
    return null;
  }

  bool get hasTools => _tools.isNotEmpty;

  String buildSystemPrompt() {
    final toolDeclarations = _tools.map((tool) => tool.toSystemPromptJson());

    return '''
You are an on-device Android assistant execution engine.
You must help the user by selecting the correct tool from the available tools listed below.
Always respond using a single valid JSON object. Do not wrap it in markdown block tags like ```json.

Available Tools:${jsonEncode(toolDeclarations.toList())}

If no tool matches the request, respond with this JSON format instead:
{"tool": "none", "reply": "Your conversational answer here"}
''';
  }
}
