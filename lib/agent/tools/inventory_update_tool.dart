import 'package:isar_community/isar.dart';

import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';
import 'medical_store.dart';

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
    final collection = isar.collection<Note>();
    final matches = await collection
        .filter()
        .titleContains(name, caseSensitive: false)
        .findAll();

    Note? target;
    Map<String, dynamic>? payload;
    for (final note in matches) {
      final decoded = decodeTypedPayload(note.content, inventoryType);
      final itemName = decoded?['name']?.toString().toLowerCase();
      if (decoded != null && itemName == name.toLowerCase()) {
        target = note;
        payload = decoded;
        break;
      }
    }

    if (target == null || payload == null) {
      return ToolResult(
        toolName: this.name,
        output: 'No inventory item found named "$name".',
        isError: true,
      );
    }

    final quantity = arguments['quantity'];
    final delta = arguments['delta'];

    if (quantity == null && delta == null && arguments['unit'] == null) {
      return ToolResult(
        toolName: this.name,
        output: 'Provide quantity, delta, or updated details to apply.',
        isError: true,
      );
    }

    final currentQty = (payload['quantity'] as num?) ?? 0;
    if (quantity != null) {
      payload['quantity'] = _parseNumber(quantity);
    } else if (delta != null) {
      payload['quantity'] = currentQty + _parseNumber(delta);
    }

    if (arguments['unit'] != null) {
      payload['unit'] = arguments['unit']?.toString().trim();
    }
    if (arguments['location'] != null) {
      payload['location'] = arguments['location']?.toString().trim();
    }
    if (arguments['expiry'] != null) {
      payload['expiry'] = arguments['expiry']?.toString().trim();
    }
    if (arguments['notes'] != null) {
      payload['notes'] = arguments['notes']?.toString().trim();
    }
    payload['updatedAt'] = DateTime.now().toIso8601String();

    target.content = encodePayload(payload);
    await isar.writeTxn(() => collection.put(target!));

    final newQty = payload['quantity'];
    final unit = payload['unit'] ?? 'units';

    return ToolResult(
      toolName: this.name,
      output: 'Updated "$name" to $newQty $unit.',
    );
  }

  num _parseNumber(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
