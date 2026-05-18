import '../../data/isar_database.dart';
import '../../data/note.dart';
import '../base_tool.dart';
import 'medical_store.dart';

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
    final quantity = _parseNumber(arguments['quantity']);
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

    final payload = buildInventoryPayload(
      name: name,
      quantity: quantity,
      unit: unit,
      location: arguments['location']?.toString().trim(),
      expiry: arguments['expiry']?.toString().trim(),
      notes: arguments['notes']?.toString().trim(),
    );

    final note = Note()
      ..title = name
      ..content = encodePayload(payload)
      ..createdAt = DateTime.now();

    final isar = _database.instance;
    await isar.writeTxn(() => isar.collection<Note>().put(note));

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
