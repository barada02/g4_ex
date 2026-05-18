import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';
import 'medical_store.dart';

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

    final payload = buildIncidentPayload(
      title: title,
      description: description,
      severity: severity,
      symptoms: arguments['symptoms']?.toString().trim(),
      actionTaken: arguments['actionTaken']?.toString().trim(),
      hasImage: arguments['hasImage'] == true,
    );

    final note = Note()
      ..title = title
      ..content = encodePayload(payload)
      ..createdAt = DateTime.now();

    final isar = _database.instance;
    await isar.writeTxn(() => isar.collection<Note>().put(note));

    return ToolResult(
      toolName: name,
      output: 'Incident "$title" recorded as $severity severity.',
    );
  }
}
