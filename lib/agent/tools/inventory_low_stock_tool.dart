import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';
import 'medical_store.dart';

class InventoryLowStockTool extends BaseTool {
  InventoryLowStockTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'inventory_low_stock';

  @override
  String get description =>
      'Use this to list items below a quantity threshold.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'threshold': {'type': 'number'},
        },
        'required': [],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final threshold = _parseNumber(arguments['threshold']) ?? 5;

    final isar = _database.instance;
    final collection = isar.collection<Note>();
    final candidates = await collection
        .filter()
        .contentContains('"type":"$inventoryType"', caseSensitive: false)
        .findAll();

    final lowStock = <Map<String, dynamic>>[];
    for (final note in candidates) {
      final payload = decodeTypedPayload(note.content, inventoryType);
      if (payload == null) {
        continue;
      }
      final qty = (payload['quantity'] as num?) ?? 0;
      if (qty <= threshold) {
        lowStock.add(payload);
      }
    }

    if (lowStock.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'All items are above $threshold units.',
      );
    }

    final buffer = StringBuffer('Low stock (<= $threshold):\n');
    for (final item in lowStock) {
      final itemName = item['name'] ?? 'Unknown';
      final qty = item['quantity'] ?? 0;
      final unit = item['unit'] ?? 'units';
      buffer.writeln('- $itemName: $qty $unit');
    }

    return ToolResult(
      toolName: name,
      output: buffer.toString().trimRight(),
    );
  }

  num? _parseNumber(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value;
    }
    return num.tryParse(value.toString());
  }
}
