import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'note.dart';

class IsarDatabase {
  IsarDatabase();

  Isar? _isar;

  bool get isReady => _isar != null;

  Isar get instance {
    final isar = _isar;
    if (isar == null) {
      throw StateError('IsarDatabase is not initialized.');
    }
    return isar;
  }

  Future<void> initialize() async {
    if (_isar != null) {
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [NoteSchema],
      directory: dir.path,
    );
  }

  Future<void> close() async {
    final isar = _isar;
    if (isar != null) {
      await isar.close();
      _isar = null;
    }
  }
}
