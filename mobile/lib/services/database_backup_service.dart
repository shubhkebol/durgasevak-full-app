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

    final db = await _databaseService.database;

    final now =
        DateTime.now().toUtc().toIso8601String();

    await db.insert(
      'app_metadata',
      {
        'key': 'local_data_version',
        'value': now,
      },
      conflictAlgorithm:
          ConflictAlgorithm.replace,
    );

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
      'Durgasevak_Backup_$timestamp.durgasevak',
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

  Future<String> validateBackup(
    String backupPath,
  ) async {
    final sourceFile = File(backupPath);

    if (!await sourceFile.exists()) {
      throw Exception(
        'Selected backup file was not found.',
      );
    }

    return _validateDatabase(sourceFile.path);
  }

  Future<String> restoreBackup(
    String backupPath,
  ) async {
    final sourceFile = File(backupPath);

    if (!await sourceFile.exists()) {
      throw Exception(
        'Selected backup file was not found.',
      );
    }

    final backupVersion =
        await _validateDatabase(sourceFile.path);

    final databasePath =
        await _databaseService.databasePath;

    final currentDatabase =
        File(databasePath);

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

      return backupVersion;
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

  Future<String?> getLocalDataVersion() async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'app_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['local_data_version'],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value'] as String?;
  }

  Future<String?> getBackupDataVersion(
    String databasePath,
  ) async {
    Database? database;

    try {
      database = await openDatabase(
        databasePath,
        readOnly: true,
      );

      final rows = await database.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['local_data_version'],
        limit: 1,
      );

      if (rows.isEmpty) {
        return null;
      }

      return rows.first['value'] as String?;
    } finally {
      await database?.close();
    }
  }

  Future<bool> isBackupNewer(
    String backupPath,
  ) async {
    final backupVersion =
        await validateBackup(backupPath);

    final localVersion =
        await getLocalDataVersion();

    if (localVersion == null ||
        localVersion.trim().isEmpty) {
      return true;
    }

    final backupDate =
        DateTime.tryParse(backupVersion);

    final localDate =
        DateTime.tryParse(localVersion);

    if (backupDate == null ||
        localDate == null) {
      throw Exception(
        'Unable to compare backup data versions.',
      );
    }

    return backupDate.isAfter(localDate);
  }

  Future<String> _validateDatabase(
    String databasePath,
  ) async {
    Database? database;

    try {
      database = await openDatabase(
        databasePath,
        readOnly: true,
      );

      final versionResult =
          await database.rawQuery(
        'PRAGMA user_version',
      );

      if (versionResult.isEmpty) {
        throw Exception(
          'Invalid Durgasevak backup: '
          'unable to read database version.',
        );
      }

      final version =
          (versionResult.first['user_version']
                      as num?)
                  ?.toInt() ??
              0;

      if (version < 8) {
        throw Exception(
          'This backup is from an older Durgasevak '
          'version. Please export the data again '
          'from the latest Admin app.',
        );
      }

      const requiredTables = [
        'users',
        'members',
        'donations',
        'expenses',
        'mohims',
        'mohim_attendance',
        'committee',
        'app_metadata',
      ];

      for (final table in requiredTables) {
        final result =
            await database.rawQuery(
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

      final metadataRows =
          await database.query(
        'app_metadata',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['local_data_version'],
        limit: 1,
      );

      if (metadataRows.isEmpty) {
        throw Exception(
          'Invalid Durgasevak backup: '
          'data version information is missing.',
        );
      }

      final versionValue =
          metadataRows.first['value'] as String?;

      if (versionValue == null ||
          DateTime.tryParse(versionValue) == null) {
        throw Exception(
          'Invalid Durgasevak backup: '
          'data version information is invalid.',
        );
      }

      return versionValue;
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