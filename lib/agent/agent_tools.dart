class ToolExecution {
  ToolExecution({required this.toolName, required this.output});

  final String toolName;
  final String output;
}

class AgentTools {
  Future<ToolExecution> execute(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    switch (toolName) {
      case 'calculate_multiplication':
        final num1 = _parseNumber(arguments['num1']);
        final num2 = _parseNumber(arguments['num2']);
        final result = num1 * num2;
        return ToolExecution(
          toolName: toolName,
          output:
              '🤖 [Tool Executed: Multiplication]\nResult: $num1 × $num2 = $result',
        );
      case 'get_battery_status':
        const int mockBatteryLevel = 78;
        return ToolExecution(
          toolName: toolName,
          output:
              '🤖 [Tool Executed: System Info]\nDevice Battery status is currently at $mockBatteryLevel%.',
        );
      case 'none':
        return ToolExecution(
          toolName: toolName,
          output: '',
        );
      default:
        return ToolExecution(
          toolName: toolName,
          output: '⚠️ Agent called an unknown tool: "$toolName"',
        );
    }
  }

  double _parseNumber(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }
}
