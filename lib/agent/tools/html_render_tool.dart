import '../base_tool.dart';

class HtmlRenderTool extends BaseTool {
  @override
  String get name => 'render_html_dashboard';

  @override
  String get description =>
      'Use this to render custom HTML/CSS dashboards or visual summaries.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'html_code': {'type': 'string'},
        },
        'required': ['html_code'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final html = arguments['html_code']?.toString().trim();
    if (html == null || html.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'Missing html_code for rendering.',
        isError: true,
      );
    }

    return ToolResult(
      toolName: name,
      output: 'Rendered HTML dashboard.',
      uiComponentType: 'html',
      uiData: {'html': html},
    );
  }
}
