import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';
import 'medical_store.dart';

class InventorySearchTool extends BaseTool {
  InventorySearchTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'inventory_search';

  @override
  String get description =>
      'Use this to find supplies by name, location, or notes.';

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
        output: 'Missing search query.',
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

    final items = <Map<String, dynamic>>[];
    for (final note in mergedById.values) {
      final payload = decodeTypedPayload(note.content, inventoryType);
      if (payload != null) {
        items.add(payload);
      }
    }

    if (items.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'No inventory items found for "$query".',
      );
    }

    final buffer = StringBuffer('Inventory matches:\n');
    for (final item in items) {
      final itemName = item['name'] ?? 'Unknown';
      final qty = item['quantity'] ?? 0;
      final unit = item['unit'] ?? 'units';
      final location = item['location']?.toString().trim();
      buffer.write('- $itemName: $qty $unit');
      if (location != null && location.isNotEmpty) {
        buffer.write(' (Location: $location)');
      }
      buffer.writeln();
    }

    return ToolResult(
      toolName: name,
      output: buffer.toString().trimRight(),
    );
  }
}
