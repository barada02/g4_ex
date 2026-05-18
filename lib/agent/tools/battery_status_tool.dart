import '../base_tool.dart';

class BatteryStatusTool extends BaseTool {
  @override
  String get name => 'get_battery_status';

  @override
  String get description =>
      'Use this when the user asks about the device battery or power level.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {},
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    const int mockBatteryLevel = 78;
    return ToolResult(
      toolName: name,
      output:
          '🤖 [Tool Executed: System Info]\nDevice Battery status is currently at $mockBatteryLevel%.',
    );
  }
}
