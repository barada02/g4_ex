import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';

class NotesDashboardTool extends BaseTool {
  NotesDashboardTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'render_notes_dashboard';

  @override
  String get description =>
      'Use this when the user asks for a visual summary or dashboard of their notes.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
        },
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final isar = _database.instance;
    final collection = isar.collection<Note>();

    final totalNotes = await collection.count();
    final recentNotes = await collection
        .where()
        .sortByCreatedAtDesc()
        .findAll();

    final latest = recentNotes.take(3).map((note) {
      return {
        'title': note.title,
        'content': note.content,
        'createdAt': note.createdAt.toIso8601String(),
      };
    }).toList();

    final title = arguments['title']?.toString().trim();

    return ToolResult(
      toolName: name,
      output: 'Rendered notes dashboard.',
      uiComponentType: 'notes_dashboard',
      uiData: {
        'title': title?.isNotEmpty == true ? title : 'Notes overview',
        'totalNotes': totalNotes,
        'latestNotes': latest,
      },
    );
  }
}
