import 'dart:typed_data';
import 'package:isar_community/isar.dart';

part 'incident_log.g.dart';

@collection
class IncidentLog {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String title;

  late String description;

  @Index(type: IndexType.value)
  late String severity; // 'low', 'medium', 'high'

  String? symptoms;

  String? actionTaken;

  List<int>? imageBytes; // Store photo attachments directly as a byte list.

  late DateTime createdAt;
}
