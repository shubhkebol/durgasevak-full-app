import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../database/database_service.dart';

class DatabaseBackupService {
  static final DatabaseBackupService instance =
      DatabaseBackupService._internal();

  final DatabaseService _databaseService =
      DatabaseService.instance;

  DatabaseBackupService._internal();

  Future<String> getDatabasePath() async {
    return _databaseService.databasePath;
  }

  Future<String> createBackup() async {
    final databasePath =
        await _databaseService.databasePath;

    final backupDirectory = Directory(
      path.join(
        path.dirname(databasePath),
        'sync_backups',
      ),
    );

    if (!await backupDirectory.exists()) {
      await backupDirectory.create(
        recursive: true,
      );
    }

    final timestamp = _timestamp();

    final backupPath = path.join(
      backupDirectory.path,
      'durgasevak_backup_$timestamp.db',
    );

    await _databaseService.closeDatabase();

    try {
      final sourceFile = File(databasePath);

      if (!await sourceFile.exists()) {
        throw Exception(
          'Local database file was not found.',
        );
      }

      await sourceFile.copy(backupPath);

      return backupPath;
    } finally {
      await _databaseService.reopenDatabase();
    }
  }

  Future<void> restoreBackup(
    String backupPath,
  ) async {
    final sourceFile = File(backupPath);

    if (!await sourceFile.exists()) {
      throw Exception(
        'Downloaded backup file was not found.',
      );
    }

    await _validateDatabase(sourceFile.path);

    final databasePath =
        await _databaseService.databasePath;

    final currentDatabase = File(databasePath);

    final temporaryDatabase =
        File('$databasePath.sync');

    final oldDatabase =
        File('$databasePath.before_sync');

    await _databaseService.closeDatabase();

    try {
      if (await temporaryDatabase.exists()) {
        await temporaryDatabase.delete();
      }

      await sourceFile.copy(
        temporaryDatabase.path,
      );

      if (await oldDatabase.exists()) {
        await oldDatabase.delete();
      }

      if (await currentDatabase.exists()) {
        await currentDatabase.rename(
          oldDatabase.path,
        );
      }

      await temporaryDatabase.rename(
        currentDatabase.path,
      );

      if (await oldDatabase.exists()) {
        await oldDatabase.delete();
      }
    } catch (_) {
      if (await currentDatabase.exists()) {
        await currentDatabase.delete();
      }

      if (await oldDatabase.exists()) {
        await oldDatabase.rename(
          currentDatabase.path,
        );
      }

      rethrow;
    } finally {
      await _deleteSidecarFiles(
        databasePath,
      );

      await _databaseService.reopenDatabase();
    }
  }

  Future<void> _validateDatabase(
    String databasePath,
  ) async {
    Database? database;

    try {
      database = await openDatabase(
        databasePath,
        readOnly: true,
      );

      const requiredTables = [
        'users',
        'members',
        'donations',
        'expenses',
        'mohims',
        'app_metadata',
      ];

      for (final table in requiredTables) {
        final result = await database.rawQuery(
          '''
          SELECT name
          FROM sqlite_master
          WHERE type = 'table'
            AND name = ?
          LIMIT 1
          ''',
          [table],
        );

        if (result.isEmpty) {
          throw Exception(
            'Invalid Durgasevak backup: '
            'missing table "$table".',
          );
        }
      }
    } finally {
      await database?.close();
    }
  }

  Future<void> _deleteSidecarFiles(
    String databasePath,
  ) async {
    final sidecars = [
      File('$databasePath-wal'),
      File('$databasePath-shm'),
      File('$databasePath-journal'),
      File('$databasePath.sync-wal'),
      File('$databasePath.sync-shm'),
      File('$databasePath.sync-journal'),
    ];

    for (final file in sidecars) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  String _timestamp() {
    final now = DateTime.now();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${now.year}'
        '${twoDigits(now.month)}'
        '${twoDigits(now.day)}_'
        '${twoDigits(now.hour)}'
        '${twoDigits(now.minute)}'
        '${twoDigits(now.second)}';
  }
}
