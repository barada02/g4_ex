import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/inventory_item.dart';
import '../base_tool.dart';

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
    final items = await isar.inventoryItems
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .locationContains(query, caseSensitive: false)
        .or()
        .notesContains(query, caseSensitive: false)
        .findAll();

    if (items.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'No inventory items found for "$query".',
      );
    }

    final buffer = StringBuffer('Inventory matches:\n');
    for (final item in items) {
      final itemName = item.name;
      final qty = item.quantity;
      final unit = item.unit;
      final location = item.location?.trim();
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
