import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/inventory_item.dart';
import '../base_tool.dart';

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
    final threshold = _parseNumber(arguments['threshold'])?.toDouble() ?? 5.0;

    final isar = _database.instance;
    final lowStock = await isar.inventoryItems
        .filter()
        .quantityLessThan(threshold)
        .or()
        .quantityEqualTo(threshold)
        .findAll();

    if (lowStock.isEmpty) {
      return ToolResult(
        toolName: name,
        output: 'All items are above $threshold units.',
      );
    }

    final buffer = StringBuffer('Low stock (<= $threshold):\n');
    for (final item in lowStock) {
      final itemName = item.name;
      final qty = item.quantity;
      final unit = item.unit;
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
