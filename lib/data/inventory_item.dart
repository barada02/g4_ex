import 'package:isar_community/isar.dart';

part 'inventory_item.g.dart';

@collection
class InventoryItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true, type: IndexType.value)
  late String name;

  late double quantity;

  late String unit;

  @Index(type: IndexType.value)
  String? location;

  DateTime? expiryDate;

  String? notes;

  late DateTime updatedAt;
}
