import '../database/database_service.dart';
import '../models/member.dart';

class MemberRepository {
  static final MemberRepository instance = MemberRepository._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  MemberRepository._internal();

  Future<List<Member>> getActiveMembers() async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'members',
      where: 'active = ?',
      whereArgs: [1],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Member.fromMap).toList();
  }

  Future<Member?> getMember(int id) async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'members',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Member.fromMap(rows.first);
  }

  Future<int> addMember(Member member) async {
    final db = await _databaseService.database;

    final data = member.toMap();
    data.remove('id');

    return db.insert('members', data);
  }

  Future<int> updateMember(Member member) async {
    if (member.id == null) {
      throw ArgumentError('Member ID is required for update');
    }

    final db = await _databaseService.database;

    final data = member.toMap();
    data.remove('id');

    return db.update('members', data, where: 'id = ?', whereArgs: [member.id]);
  }

  Future<int> deactivateMember(int id) async {
    final db = await _databaseService.database;

    return db.update(
      'members',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
