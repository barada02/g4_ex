import 'dart:typed_data';
import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/incident_log.dart';
import '../base_tool.dart';

class IncidentLogTool extends BaseTool {
  IncidentLogTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'incident_log';

  @override
  String get description =>
      'Use this to record an injury, symptom, or incident for later review.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'description': {'type': 'string'},
          'severity': {
            'type': 'string',
            'enum': ['low', 'medium', 'high'],
          },
          'symptoms': {'type': 'string'},
          'actionTaken': {'type': 'string'},
          'hasImage': {'type': 'boolean'},
        },
        'required': ['title', 'description', 'severity'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final title = arguments['title']?.toString().trim();
    final description = arguments['description']?.toString().trim();
    final severity = arguments['severity']?.toString().trim();

    if (title == null || title.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'Missing incident title.',
        isError: true,
      );
    }

    if (description == null || description.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'Missing incident description.',
        isError: true,
      );
    }

    if (severity == null || severity.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'Missing severity level.',
        isError: true,
      );
    }

    // Extract raw image bytes passed in arguments (if any)
    final dynamic rawImage = arguments['imageBytes'];
    List<int>? imageBytes;
    if (rawImage is List<int>) {
      imageBytes = rawImage;
    }

    final isar = _database.instance;

    final log = IncidentLog()
      ..title = title
      ..description = description
      ..severity = severity
      ..symptoms = arguments['symptoms']?.toString().trim()
      ..actionTaken = arguments['actionTaken']?.toString().trim()
      ..imageBytes = imageBytes
      ..createdAt = DateTime.now();

    await isar.writeTxn(() => isar.incidentLogs.put(log));

    return ToolResult(
      toolName: name,
      output: 'Incident "$title" recorded as $severity severity.',
    );
  }
}
