class ToolResult {
  ToolResult({
    required this.toolName,
    required this.output,
    this.isError = false,
  });

  final String toolName;
  final String output;
  final bool isError;
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
