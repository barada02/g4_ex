import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';

class NoteClearTool extends BaseTool {
  NoteClearTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'db_delete_all_notes';

  @override
  String get description =>
      'Use this only when the user explicitly requests to clear or delete everything.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {},
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final isar = _database.instance;
    final collection = isar.collection<Note>();
    final count = await collection.count();
    await isar.writeTxn(collection.clear);

    return ToolResult(
      toolName: name,
      output: '🗑️ [Database]: Cleared $count note(s).',
    );
  }
}
