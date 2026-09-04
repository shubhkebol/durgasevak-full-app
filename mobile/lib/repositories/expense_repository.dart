import '../database/database_service.dart';
import '../models/expense.dart';

class ExpenseRepository {
  static final ExpenseRepository instance =
      ExpenseRepository._internal();

  final DatabaseService _databaseService =
      DatabaseService.instance;

  ExpenseRepository._internal();

  Future<List<Expense>> getActiveExpenses({
    String search = '',
  }) async {
    final db = await _databaseService.database;

    final hasSearch = search.trim().isNotEmpty;

    final query = '''
      SELECT *
      FROM expenses
      WHERE active = 1
      ${hasSearch ? '''
        AND (
          category LIKE ?
          OR note LIKE ?
          OR CAST(amount AS TEXT) LIKE ?
        )
      ''' : ''}
      ORDER BY date DESC, id DESC
    ''';

    if (!hasSearch) {
      final rows = await db.rawQuery(query);

      return rows.map(Expense.fromMap).toList();
    }

    final searchValue = '%${search.trim()}%';

    final rows = await db.rawQuery(
      query,
      [
        searchValue,
        searchValue,
        searchValue,
      ],
    );

    return rows.map(Expense.fromMap).toList();
  }

  Future<Expense?> getExpense(int id) async {
    final db = await _databaseService.database;

    final rows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Expense.fromMap(rows.first);
  }

  Future<int> addExpense(
    Expense expense,
  ) async {
    final db = await _databaseService.database;

    final data = expense.toMap();

    data.remove('id');

    return db.insert(
      'expenses',
      data,
    );
  }

  Future<int> updateExpense(
    Expense expense,
  ) async {
    if (expense.id == null) {
      throw ArgumentError(
        'Expense ID is required for update',
      );
    }

    final db = await _databaseService.database;

    final data = expense.toMap();

    data.remove('id');

    return db.update(
      'expenses',
      data,
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deactivateExpense(
    int id,
  ) async {
    final db = await _databaseService.database;

    return db.update(
      'expenses',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalActiveExpenses() async {
    final db = await _databaseService.database;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE active = 1
    ''');

    return (result.first['total'] as num).toDouble();
  }
}
