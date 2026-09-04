import '../database/database_service.dart';

class ReportRepository {
  static final ReportRepository instance =
      ReportRepository._internal();

  final DatabaseService _databaseService =
      DatabaseService.instance;

  ReportRepository._internal();

  Future<Map<String, double>>
      getFinancialSummary({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseService.database;

    final dateCondition =
        _dateCondition(
      column: 'date',
      startDate: startDate,
      endDate: endDate,
    );

    final args = <dynamic>[
  ?startDate,
  ?endDate,
];

    final donationResult =
        await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM donations
      WHERE active = 1
      $dateCondition
      ''',
      args,
    );

    final expenseResult =
        await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE active = 1
      $dateCondition
      ''',
      args,
    );

    final donations =
        (donationResult.first['total']
                as num)
            .toDouble();

    final expenses =
        (expenseResult.first['total']
                as num)
            .toDouble();

    return {
      'donations': donations,
      'expenses': expenses,
      'balance': donations - expenses,
    };
  }

  Future<List<Map<String, dynamic>>>
      getDonationReport({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseService.database;

    final condition = _dateCondition(
      column: 'donations.date',
      startDate: startDate,
      endDate: endDate,
    );

    final args = <dynamic>[
  ?startDate,
  ?endDate,
];

    return db.rawQuery(
      '''
      SELECT
        donations.*,
        members.name AS member_name
      FROM donations
      LEFT JOIN members
        ON donations.member_id = members.id
      WHERE donations.active = 1
      $condition
      ORDER BY
        donations.date DESC,
        donations.id DESC
      ''',
      args,
    );
  }

  Future<List<Map<String, dynamic>>>
      getExpenseReport({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseService.database;

    final condition = _dateCondition(
      column: 'expenses.date',
      startDate: startDate,
      endDate: endDate,
    );

    final args = <dynamic>[
  ?startDate,
  ?endDate,
];

    return db.rawQuery(
      '''
      SELECT *
      FROM expenses
      WHERE active = 1
      $condition
      ORDER BY
        date DESC,
        id DESC
      ''',
      args,
    );
  }

  Future<List<Map<String, dynamic>>>
      getMemberWiseDonations({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseService.database;

    final condition = _dateCondition(
      column: 'donations.date',
      startDate: startDate,
      endDate: endDate,
    );

    final args = <dynamic>[
  ?startDate,
  ?endDate,
];

    return db.rawQuery(
      '''
      SELECT
        members.id AS member_id,
        members.name AS member_name,
        COUNT(donations.id) AS donation_count,
        COALESCE(SUM(donations.amount), 0)
          AS total_amount
      FROM donations
      INNER JOIN members
        ON donations.member_id = members.id
      WHERE donations.active = 1
        AND donations.donor_type = 'member'
      $condition
      GROUP BY
        members.id,
        members.name
      ORDER BY
        total_amount DESC,
        members.name COLLATE NOCASE ASC
      ''',
      args,
    );
  }

  Future<List<Map<String, dynamic>>>
      getMonthlyDonationSummary({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseService.database;

    final condition = _dateCondition(
      column: 'date',
      startDate: startDate,
      endDate: endDate,
    );

    final args = <dynamic>[
  ?startDate,
  ?endDate,
];

    return db.rawQuery(
      '''
      SELECT
        strftime('%Y-%m', date) AS month,
        COUNT(id) AS donation_count,
        COALESCE(SUM(amount), 0)
          AS total_amount
      FROM donations
      WHERE active = 1
      $condition
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month DESC
      ''',
      args,
    );
  }

  Future<List<Map<String, dynamic>>>
      getOtherDonorSummary({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseService.database;

    final condition = _dateCondition(
      column: 'date',
      startDate: startDate,
      endDate: endDate,
    );

    final args = <dynamic>[
  ?startDate,
  ?endDate,
];

    return db.rawQuery(
      '''
      SELECT
        COALESCE(
          NULLIF(TRIM(donor_name), ''),
          'Other Donor'
        ) AS donor_name,
        COUNT(id) AS donation_count,
        COALESCE(SUM(amount), 0)
          AS total_amount
      FROM donations
      WHERE active = 1
        AND donor_type = 'other'
      $condition
      GROUP BY
        COALESCE(
          NULLIF(TRIM(donor_name), ''),
          'Other Donor'
        )
      ORDER BY
        total_amount DESC,
        donor_name COLLATE NOCASE ASC
      ''',
      args,
    );
  }

  String _dateCondition({
    required String column,
    String? startDate,
    String? endDate,
  }) {
    final conditions = <String>[];

    if (startDate != null) {
      conditions.add(
        '$column >= ?',
      );
    }

    if (endDate != null) {
      conditions.add(
        '$column < ?',
      );
    }

    if (conditions.isEmpty) {
      return '';
    }

    return 'AND ${conditions.join(' AND ')}';
  }
}
