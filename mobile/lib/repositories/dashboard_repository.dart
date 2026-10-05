import '../database/database_service.dart';

class DashboardSummary {
  final int activeMembers;
  final double totalDonations;
  final double totalExpenses;
  final double monthlyDonations;
  final double otherDonations;

  const DashboardSummary({
    required this.activeMembers,
    required this.totalDonations,
    required this.totalExpenses,
    required this.monthlyDonations,
    required this.otherDonations,
  });

  double get balance => totalDonations - totalExpenses;
}

class DashboardRepository {
  static final DashboardRepository instance = DashboardRepository._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  DashboardRepository._internal();

  Future<DashboardSummary> getSummary() async {
    final db = await _databaseService.database;

    final memberResult = await db.rawQuery('''
      SELECT COUNT(*) AS total
      FROM members
      WHERE active = 1
    ''');

    final donationResult = await db.rawQuery('''
      SELECT
        COALESCE(SUM(amount), 0) AS total,
        COALESCE(
          SUM(
            CASE
              WHEN monthly_donation = 1
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS monthly
      FROM donations
      WHERE active = 1
    ''');

    final expenseResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE active = 1
    ''');

    final otherDonationResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM donations
      WHERE active = 1
        AND donor_type = 'other'
    ''');

    return DashboardSummary(
      activeMembers: (memberResult.first['total'] as num).toInt(),
      totalDonations: (donationResult.first['total'] as num).toDouble(),
      totalExpenses: (expenseResult.first['total'] as num).toDouble(),
      monthlyDonations: (donationResult.first['monthly'] as num).toDouble(),
      otherDonations: (otherDonationResult.first['total'] as num).toDouble(),
    );
  }

  Future<double> getCurrentMonthDonations() async {
    final db = await _databaseService.database;

    final now = DateTime.now();

    final start =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-01';

    final nextMonth = DateTime(now.year, now.month + 1, 1);

    final end =
        '${nextMonth.year.toString().padLeft(4, '0')}-'
        '${nextMonth.month.toString().padLeft(2, '0')}-01';

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM donations
      WHERE active = 1
        AND date >= ?
        AND date < ?
      ''',
      [start, end],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getRecentDonations({int limit = 5}) async {
    final db = await _databaseService.database;

    return db.rawQuery(
      '''
      SELECT
        donations.*,
        members.name AS member_name
      FROM donations
      LEFT JOIN members
        ON donations.member_id = members.id
      WHERE donations.active = 1
      ORDER BY donations.date DESC,
               donations.id DESC
      LIMIT ?
      ''',
      [limit],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentExpenses({int limit = 5}) async {
    final db = await _databaseService.database;

    return db.rawQuery(
      '''
      SELECT *
      FROM expenses
      WHERE active = 1
      ORDER BY date DESC,
               id DESC
      LIMIT ?
      ''',
      [limit],
    );
  }
}
