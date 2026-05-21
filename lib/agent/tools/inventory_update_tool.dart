import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/inventory_item.dart';
import '../base_tool.dart';

class InventoryUpdateTool extends BaseTool {
  InventoryUpdateTool(this._database);

  final IsarDatabase _database;

  @override
  String get name => 'inventory_update_item';

  @override
  String get description =>
      'Use this to update quantity or details for an existing supply item.';

  @override
  Map<String, dynamic> get argumentsSchema => {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'quantity': {'type': 'number'},
          'delta': {'type': 'number'},
          'unit': {'type': 'string'},
          'location': {'type': 'string'},
          'expiry': {'type': 'string'},
          'notes': {'type': 'string'},
        },
        'required': ['name'],
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> arguments) async {
    final name = arguments['name']?.toString().trim();
    if (name == null || name.isEmpty) {
      return ToolResult(
        toolName: this.name,
        output: 'Missing item name to update.',
        isError: true,
      );
    }

    final isar = _database.instance;
    
    // First try exact match
    var item = await isar.inventoryItems
        .filter()
        .nameEqualTo(name, caseSensitive: false)
        .findFirst();

    // Fallback to contains match if not found exactly
    if (item == null) {
      item = await isar.inventoryItems
          .filter()
          .nameContains(name, caseSensitive: false)
          .findFirst();
    }

    if (item == null) {
      return ToolResult(
        toolName: this.name,
        output: 'No inventory item found named "$name".',
        isError: true,
      );
    }

    final quantity = arguments['quantity'];
    final delta = arguments['delta'];

    if (quantity == null && delta == null && arguments['unit'] == null &&
        arguments['location'] == null && arguments['expiry'] == null && 
        arguments['notes'] == null) {
      return ToolResult(
        toolName: this.name,
        output: 'Provide quantity, delta, or updated details to apply.',
        isError: true,
      );
    }

    if (quantity != null) {
      item.quantity = _parseNumber(quantity).toDouble();
    } else if (delta != null) {
      item.quantity += _parseNumber(delta).toDouble();
    }

    if (arguments['unit'] != null) {
      item.unit = arguments['unit']?.toString().trim() ?? item.unit;
    }
    if (arguments['location'] != null) {
      item.location = arguments['location']?.toString().trim();
    }
    if (arguments['expiry'] != null) {
      final expiryStr = arguments['expiry']?.toString().trim() ?? '';
      item.expiryDate = expiryStr.isNotEmpty ? DateTime.tryParse(expiryStr) : null;
    }
    if (arguments['notes'] != null) {
      item.notes = arguments['notes']?.toString().trim();
    }
    item.updatedAt = DateTime.now();

    await isar.writeTxn(() => isar.inventoryItems.put(item!));

    return ToolResult(
      toolName: this.name,
      output: 'Updated "${item.name}" to ${item.quantity} ${item.unit}.',
    );
  }

  num _parseNumber(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
