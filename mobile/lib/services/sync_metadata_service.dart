import 'package:sqflite/sqflite.dart';

import '../database/database_service.dart';

class SyncMetadataService {
  static final SyncMetadataService instance = SyncMetadataService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  SyncMetadataService._internal();

  Future<String?> get(String key) async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await _databaseService.database;

    await db.insert('app_metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String key) async {
    final db = await _databaseService.database;

    await db.delete('app_metadata', where: 'key = ?', whereArgs: [key]);
  }
}
