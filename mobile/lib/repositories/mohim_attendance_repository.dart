import 'package:sqflite/sqflite.dart';

import '../database/database_service.dart';
import '../models/member.dart';
import '../models/mohim_attendance.dart';

class MohimAttendanceRepository {
  static final MohimAttendanceRepository instance =
      MohimAttendanceRepository._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  MohimAttendanceRepository._internal();

  Future<List<Member>> getActiveMembers() async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'members',
      where: 'active = 1',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Member.fromMap).toList();
  }

  Future<List<MohimAttendance>> getAttendance(int mohimId) async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'mohim_attendance',
      where: 'mohim_id = ?',
      whereArgs: [mohimId],
      orderBy: 'id ASC',
    );

    return rows.map(MohimAttendance.fromMap).toList();
  }

  Future<Set<int>> getPresentMemberIds(int mohimId) async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'mohim_attendance',
      columns: ['member_id'],
      where: '''
        mohim_id = ?
        AND member_id IS NOT NULL
      ''',
      whereArgs: [mohimId],
    );

    return rows.map((row) => row['member_id']).whereType<int>().toSet();
  }

  Future<List<String>> getOtherVisitors(int mohimId) async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'mohim_attendance',
      columns: ['id', 'visitor_name'],
      where: '''
        mohim_id = ?
        AND member_id IS NULL
        AND visitor_name IS NOT NULL
      ''',
      whereArgs: [mohimId],
      orderBy: 'id ASC',
    );

    return rows
        .map((row) => row['visitor_name'] as String?)
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList();
  }

  Future<void> markMemberPresent({
    required int mohimId,
    required int memberId,
  }) async {
    final db = await _databaseService.database;

    await db.insert('mohim_attendance', {
      'mohim_id': mohimId,
      'member_id': memberId,
      'visitor_name': null,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> markMemberAbsent({
    required int mohimId,
    required int memberId,
  }) async {
    final db = await _databaseService.database;

    await db.delete(
      'mohim_attendance',
      where: '''
        mohim_id = ?
        AND member_id = ?
      ''',
      whereArgs: [mohimId, memberId],
    );
  }

  Future<void> addOtherVisitor({
    required int mohimId,
    required String visitorName,
  }) async {
    final name = visitorName.trim();

    if (name.isEmpty) {
      throw Exception('Visitor name cannot be empty.');
    }

    final db = await _databaseService.database;

    await db.insert('mohim_attendance', {
      'mohim_id': mohimId,
      'member_id': null,
      'visitor_name': name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeOtherVisitor({
    required int mohimId,
    required String visitorName,
  }) async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'mohim_attendance',
      columns: ['id'],
      where: '''
        mohim_id = ?
        AND member_id IS NULL
        AND visitor_name = ?
      ''',
      whereArgs: [mohimId, visitorName],
      orderBy: 'id DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return;
    }

    await db.delete(
      'mohim_attendance',
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
  }

  Future<int> getPresentMemberCount(int mohimId) async {
    final db = await _databaseService.database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM mohim_attendance
      WHERE mohim_id = ?
        AND member_id IS NOT NULL
      ''',
      [mohimId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getOtherVisitorCount(int mohimId) async {
    final db = await _databaseService.database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM mohim_attendance
      WHERE mohim_id = ?
        AND member_id IS NULL
        AND visitor_name IS NOT NULL
        AND TRIM(visitor_name) != ''
      ''',
      [mohimId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
}
