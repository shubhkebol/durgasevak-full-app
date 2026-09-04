import '../database/database_service.dart';
import '../models/committee.dart';

class CommitteeRepository {
  static final CommitteeRepository instance = CommitteeRepository._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  CommitteeRepository._internal();

  Future<List<Committee>> getAll() async {
    final db = await _databaseService.database;

    final rows = await db.rawQuery('''
      SELECT
        c.id,
        c.position,
        c.member_id,
        m.name AS member_name,
        m.mobile,
        c.created_at,
        c.updated_at
      FROM committee c
      INNER JOIN members m
        ON m.id = c.member_id
      ORDER BY c.id ASC
    ''');

    return rows.map(Committee.fromMap).toList();
  }

  Future<void> add({required String position, required int memberId}) async {
    final db = await _databaseService.database;

    final now = DateTime.now().toIso8601String();

    await db.insert('committee', {
      'position': position.trim(),
      'member_id': memberId,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> update({
    required int id,
    required String position,
    required int memberId,
  }) async {
    final db = await _databaseService.database;

    await db.update(
      'committee',
      {
        'position': position.trim(),
        'member_id': memberId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _databaseService.database;

    await db.delete('committee', where: 'id = ?', whereArgs: [id]);
  }
}
