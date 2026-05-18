import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';

class NoteInsertTool extends BaseTool {
  NoteInsertTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'db_insert_note';

  @override
  String get description =>
      'Use this when the user wants to remember, save, write, or log an entry.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['title', 'content'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final title = arguments['title']?.toString().trim();
    final content = arguments['content']?.toString().trim();

    if (title == null || title.isEmpty) {
      return ToolResult(
        toolName: name,
        output: '⚠️ Missing note title.',
        isError: true,
      );
    }

    if (content == null || content.isEmpty) {
      return ToolResult(
        toolName: name,
        output: '⚠️ Missing note content.',
        isError: true,
      );
    }

    final note = Note()
      ..title = title
      ..content = content
      ..createdAt = DateTime.now();

    final isar = _database.instance;
    await isar.writeTxn(() => isar.collection<Note>().put(note));

    return ToolResult(
      toolName: name,
      output: '💾 [Database]: Note saved as "$title".',
    );
  }
}
