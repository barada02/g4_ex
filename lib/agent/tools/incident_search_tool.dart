import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';
import 'medical_store.dart';

class IncidentSearchTool extends BaseTool {
  IncidentSearchTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'incident_search';

  @override
  String get description =>
      'Use this to find past incidents by keyword or severity.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final query = arguments['query']?.toString().trim() ?? '';
    if (query.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'Missing incident search query.',
        isError: true,
      );
    }

    final isar = _database.instance;
    final collection = isar.collection<Note>();
    final titleMatches = await collection
        .filter()
        .titleContains(query, caseSensitive: false)
        .findAll();
    final contentMatches = await collection
        .filter()
        .contentContains(query, caseSensitive: false)
        .findAll();

    final mergedById = <int, Note>{
      for (final note in titleMatches) note.id: note,
      for (final note in contentMatches) note.id: note,
    };

    final incidents = <Map<String, dynamic>>[];
    for (final note in mergedById.values) {
      final payload = decodeTypedPayload(note.content, incidentType);
      if (payload != null) {
        incidents.add(payload);
      }
    }

    if (incidents.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'No incidents found for "$query".',
      );
    }

    final buffer = StringBuffer('Incident matches:\n');
    for (final incident in incidents) {
      final title = incident['title'] ?? 'Untitled incident';
      final severity = incident['severity'] ?? 'unknown';
      buffer.writeln('- $title (severity: $severity)');
    }

    return ToolResult(
      toolName: name,
      output: buffer.toString().trimRight(),
    );
  }
}
