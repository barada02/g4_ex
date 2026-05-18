import 'package:isar/isar.dart';

import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';

class NoteSearchTool extends BaseTool {
  NoteSearchTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'db_search_notes';

  @override
  String get description =>
      'Use this when the user asks to find, check, search, or look up previous records.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'searchTerm': {'type': 'string'},
        },
        'required': ['searchTerm'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final term = arguments['searchTerm']?.toString().trim() ?? '';
    if (term.isEmpty) {
      return ToolResult(
        toolName: name,
        output: '⚠️ Missing search term.',
        isError: true,
      );
    }

    final isar = _database.instance;
    final collection = isar.collection<Note>();
    final titleMatches = await collection
      .filter()
      .titleContains(term, caseSensitive: false)
      .findAll();
    final contentMatches = await collection
      .filter()
      .contentContains(term, caseSensitive: false)
      .findAll();

    final mergedById = <int, Note>{
      for (final note in titleMatches) note.id: note,
      for (final note in contentMatches) note.id: note,
    };

    final matches = mergedById.values.toList();

    if (matches.isEmpty) {
      return ToolResult(
        toolName: name,
        output: '🔍 [Database]: No matches for "$term".',
      );
    }

    final buffer = StringBuffer(
      '🔍 [Database]: Found ${matches.length} match(es) for "$term":\n',
    );
    for (final note in matches) {
      buffer.writeln('- ${note.title}: ${note.content}');
    }

    return ToolResult(toolName: name, output: buffer.toString().trimRight());
  }
}
