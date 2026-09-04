import '../database/database_service.dart';
import '../models/mohim.dart';

class MohimRepository {
  static final MohimRepository instance = MohimRepository._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  MohimRepository._internal();

  Future<List<Mohim>> getActiveMohims({String search = ''}) async {
    final db = await _databaseService.database;

    final trimmedSearch = search.trim();

    final List<Map<String, dynamic>> rows;

    if (trimmedSearch.isEmpty) {
      rows = await db.query('mohims', where: 'active = 1', orderBy: 'id DESC');
    } else {
      rows = await db.query(
        'mohims',
        where: '''
          active = 1
          AND (
            name LIKE ?
            OR description LIKE ?
          )
        ''',
        whereArgs: ['%$trimmedSearch%', '%$trimmedSearch%'],
        orderBy: 'id DESC',
      );
    }

    return rows.map(Mohim.fromMap).toList();
  }

  Future<List<Mohim>> getAllMohims() async {
    final db = await _databaseService.database;

    final rows = await db.query('mohims', orderBy: 'id DESC');

    return rows.map(Mohim.fromMap).toList();
  }

  Future<Mohim?> getMohimById(int id) async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'mohims',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Mohim.fromMap(rows.first);
  }

  Future<int> addMohim(Mohim mohim) async {
    final db = await _databaseService.database;

    final map = mohim.toMap();

    map.remove('id');

    return db.insert('mohims', map);
  }

  Future<int> updateMohim(Mohim mohim) async {
    if (mohim.id == null) {
      throw Exception('Cannot update Mohim without an ID.');
    }

    final db = await _databaseService.database;

    final map = mohim.toMap();

    map.remove('id');

    return db.update('mohims', map, where: 'id = ?', whereArgs: [mohim.id]);
  }

  Future<int> deactivateMohim(int id) async {
    final db = await _databaseService.database;

    return db.update('mohims', {'active': 0}, where: 'id = ?', whereArgs: [id]);
  }
}
