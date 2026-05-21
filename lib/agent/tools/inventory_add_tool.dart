import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/inventory_item.dart';
import '../base_tool.dart';

class InventoryAddTool extends BaseTool {
  InventoryAddTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'inventory_add_item';

  @override
  String get description =>
      'Use this to add a medical supply item with quantity and optional details.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'quantity': {'type': 'number'},
          'unit': {'type': 'string'},
          'location': {'type': 'string'},
          'expiry': {'type': 'string'},
          'notes': {'type': 'string'},
        },
        'required': ['name', 'quantity', 'unit'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final name = arguments['name']?.toString().trim();
    final quantity = _parseNumber(arguments['quantity']).toDouble();
    final unit = arguments['unit']?.toString().trim();

    if (name == null || name.isEmpty) {
      return ToolResult(
        toolName: this.name,
        output: 'Missing item name.',
        isError: true,
      );
    }

    if (unit == null || unit.isEmpty) {
      return ToolResult(
        toolName: this.name,
        output: 'Missing unit (e.g., packs, rolls, tablets).',
        isError: true,
      );
    }

    if (quantity <= 0) {
      return ToolResult(
        toolName: this.name,
        output: 'Quantity must be greater than zero.',
        isError: true,
      );
    }

    final expiryStr = arguments['expiry']?.toString().trim();
    final expiryDate = expiryStr != null && expiryStr.isNotEmpty
        ? DateTime.tryParse(expiryStr)
        : null;

    final isar = _database.instance;

    final item = InventoryItem()
      ..name = name
      ..quantity = quantity
      ..unit = unit
      ..location = arguments['location']?.toString().trim()
      ..expiryDate = expiryDate
      ..notes = arguments['notes']?.toString().trim()
      ..updatedAt = DateTime.now();

    await isar.writeTxn(() => isar.inventoryItems.put(item));

    return ToolResult(
      toolName: this.name,
      output: 'Added "$name" with $quantity $unit.',
    );
  }

  num _parseNumber(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
