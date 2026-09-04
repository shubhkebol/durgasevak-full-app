import '../database/database_service.dart';
import '../models/donation.dart';

class DonationRepository {
  static final DonationRepository instance =
      DonationRepository._internal();

  final DatabaseService _databaseService =
      DatabaseService.instance;

  DonationRepository._internal();

  Future<List<Donation>> getActiveDonations({
    String search = '',
  }) async {
    final db = await _databaseService.database;

    final hasSearch = search.trim().isNotEmpty;

    final query = '''
      SELECT
        donations.*,
        members.name AS member_name
      FROM donations
      LEFT JOIN members
        ON donations.member_id = members.id
      WHERE donations.active = 1
      ${hasSearch ? '''
        AND (
          members.name LIKE ?
          OR donations.donor_name LIKE ?
          OR donations.note LIKE ?
          OR CAST(donations.amount AS TEXT) LIKE ?
        )
      ''' : ''}
      ORDER BY donations.date DESC, donations.id DESC
    ''';

    if (!hasSearch) {
      final rows = await db.rawQuery(query);

      return rows.map(Donation.fromMap).toList();
    }

    final searchValue = '%${search.trim()}%';

    final rows = await db.rawQuery(
      query,
      [
        searchValue,
        searchValue,
        searchValue,
        searchValue,
      ],
    );

    return rows.map(Donation.fromMap).toList();
  }

  Future<Donation?> getDonation(int id) async {
    final db = await _databaseService.database;

    final rows = await db.rawQuery(
      '''
      SELECT
        donations.*,
        members.name AS member_name
      FROM donations
      LEFT JOIN members
        ON donations.member_id = members.id
      WHERE donations.id = ?
      LIMIT 1
      ''',
      [id],
    );

    if (rows.isEmpty) {
      return null;
    }

    return Donation.fromMap(rows.first);
  }

  Future<int> addDonation(
    Donation donation,
  ) async {
    final db = await _databaseService.database;

    final data = donation.toMap();

    data.remove('id');

    return db.insert(
      'donations',
      data,
    );
  }

  Future<int> updateDonation(
    Donation donation,
  ) async {
    if (donation.id == null) {
      throw ArgumentError(
        'Donation ID is required for update',
      );
    }

    final db = await _databaseService.database;

    final data = donation.toMap();

    data.remove('id');

    return db.update(
      'donations',
      data,
      where: 'id = ?',
      whereArgs: [donation.id],
    );
  }

  Future<int> deactivateDonation(
    int id,
  ) async {
    final db = await _databaseService.database;

    return db.update(
      'donations',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalActiveDonations() async {
    final db = await _databaseService.database;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM donations
      WHERE active = 1
    ''');

    return (result.first['total'] as num).toDouble();
  }
}