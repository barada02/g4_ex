class ToolResult {
  ToolResult({
    required this.toolName,
    required this.output,
    this.isError = false,
    this.uiComponentType,
    this.uiData,
  });

  final String toolName;
  final String output;
  final bool isError;
  final String? uiComponentType;
  final Map<String, dynamic>? uiData;
}

abstract class BaseTool {
  String get name;
  String get description;
  Map<String, dynamic> get argumentsSchema;

  Future<ToolResult> execute(Map<String, dynamic> arguments);

  Map<String, dynamic> toSystemPromptJson() {
    return {
      'tool': name,
      'description': description,
      'arguments': argumentsSchema,
    };
  }
}
