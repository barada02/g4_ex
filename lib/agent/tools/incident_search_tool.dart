import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/incident_log.dart';
import '../base_tool.dart';

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
    final incidents = await isar.incidentLogs
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .descriptionContains(query, caseSensitive: false)
        .or()
        .symptomsContains(query, caseSensitive: false)
        .or()
        .severityEqualTo(query, caseSensitive: false)
        .findAll();

    if (incidents.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'No incidents found for "$query".',
      );
    }

    final buffer = StringBuffer('Incident matches:\n');
    for (final incident in incidents) {
      final title = incident.title;
      final severity = incident.severity;
      buffer.writeln('- $title (severity: $severity)');
    }

    return ToolResult(
      toolName: name,
      output: buffer.toString().trimRight(),
    );
  }
}
