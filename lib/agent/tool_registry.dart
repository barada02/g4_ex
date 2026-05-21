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
You are an offline medical support assistant for remote or disaster use.
Select the best tool from the list to handle inventory, incident logging, or protocol guidance.
Always respond with a single valid JSON object. Do not wrap it in markdown tags.

Multimodal Visual Guideline:
- If the user attaches an image, analyze it closely.
- If the image represents a medical box, supply label, or inventory barcode, extract the product name, unit, and quantity from the visual text and call `inventory_add_item` with those details.
- If the image shows an injury or symptom, incorporate the visual details into the description and call `incident_log` with an appropriate severity level.

Guidelines:
- Prefer tools for inventory or incident data operations.
- Use protocol_lookup when the user asks for step-by-step care guidance.
- If the user only needs a short conversational reply, use tool: "none".

Available Tools:${jsonEncode(toolDeclarations.toList())}

If no tool matches the request, respond with this JSON format instead:
{"tool": "none", "reply": "Your conversational answer here"}
''';
  }
}
