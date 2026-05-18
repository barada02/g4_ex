import '../base_tool.dart';

class UiRenderTool extends BaseTool {
  @override
  String get name => 'render_ui_component';

  @override
  String get description =>
      'Use this when the user asks for a visual summary, dashboard, charts, '
      'or any structured UI card in the chat.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'component_type': {'type': 'string'},
          'data': {'type': 'object'},
        },
        'required': ['component_type', 'data'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final componentType = arguments['component_type']?.toString().trim();
    final data = arguments['data'] as Map<String, dynamic>?;

    if (componentType == null || componentType.isEmpty) {
      return ToolResult(
        toolName: name,
        output: '⚠️ Missing component_type for UI rendering.',
        isError: true,
      );
    }

    return ToolResult(
      toolName: name,
      output: 'Rendered UI component: $componentType',
      uiComponentType: componentType,
      uiData: data ?? <String, dynamic>{},
    );
  }
}
