import '../base_tool.dart';

class MultiplicationTool extends BaseTool {
  @override
  String get name => 'calculate_multiplication';

  @override
  String get description =>
      'Use this only when the user explicitly asks to multiply two numbers.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'num1': {'type': 'number'},
          'num2': {'type': 'number'},
        },
        'required': ['num1', 'num2'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final num1 = _parseNumber(arguments['num1']);
    final num2 = _parseNumber(arguments['num2']);
    final result = num1 * num2;
    return ToolResult(
      toolName: name,
      output:
          '🤖 [Tool Executed: Multiplication]\nResult: $num1 × $num2 = $result',
    );
  }

  double _parseNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
