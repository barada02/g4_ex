import '../base_tool.dart';

class HtmlRenderTool extends BaseTool {
  @override
  String get name => 'generate_custom_html_view';

  @override
  String get description =>
      'Use this when the user asks for a unique dashboard layout, formatted '
      'tables, invoices, or stylized lists best represented as HTML.'
      'Use this when you think its best to render a custom HTML view for the user instead of plain text or a predefined UI component.'
      ;

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
        output: '⚠️ Missing html_code for HTML rendering.',
        isError: true,
      );
    }

    return ToolResult(
      toolName: name,
      output: 'Rendered HTML view.',
      uiComponentType: 'html',
      uiData: {'html': html},
    );
  }
}
