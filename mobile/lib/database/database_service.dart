import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();

  static Database? _database;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<String> get databasePath async {
    final databasePath = await getDatabasesPath();

    return join(databasePath, 'durgasevak.db');
  }

  Future<void> closeDatabase() async {
    final db = _database;

    _database = null;

    if (db != null) {
      await db.close();
    }
  }

  Future<void> reopenDatabase() async {
    _database = await _initDatabase();
  }

  Future<Database> _initDatabase() async {
    final path = await databasePath;

    return openDatabase(
      path,
      version: 8,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        mobile TEXT,
        address TEXT,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE donations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        member_id INTEGER,
        donor_type TEXT NOT NULL DEFAULT 'member',
        donor_name TEXT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        monthly_donation INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        category TEXT,
        note TEXT,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE mohims (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        description TEXT,
        active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE mohim_attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mohim_id INTEGER NOT NULL,
        member_id INTEGER,
        visitor_name TEXT,
        created_at TEXT NOT NULL,
        UNIQUE(mohim_id, member_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE committee (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        position TEXT NOT NULL UNIQUE,
        member_id INTEGER NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _seedDefaultUsers(db);
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _seedDefaultUsers(db);
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS donations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          member_id INTEGER,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          active INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        ALTER TABLE donations
        ADD COLUMN donor_type TEXT
        NOT NULL
        DEFAULT 'member'
      ''');

      await db.execute('''
        ALTER TABLE donations
        ADD COLUMN donor_name TEXT
      ''');

      await db.execute('''
        UPDATE donations
        SET donor_type = CASE
          WHEN member_id IS NOT NULL THEN 'member'
          ELSE 'other'
        END
      ''');

      await db.execute('''
        UPDATE donations
        SET donor_name = 'General Donation'
        WHERE member_id IS NULL
          AND (
            donor_name IS NULL
            OR TRIM(donor_name) = ''
          )
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        ALTER TABLE donations
        ADD COLUMN monthly_donation INTEGER
        NOT NULL
        DEFAULT 0
      ''');
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          category TEXT,
          note TEXT,
          active INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mohim_attendance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          mohim_id INTEGER NOT NULL,
          member_id INTEGER,
          visitor_name TEXT,
          created_at TEXT NOT NULL,
          UNIQUE(mohim_id, member_id)
        )
      ''');
    }

    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS committee (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          position TEXT NOT NULL UNIQUE,
          member_id INTEGER NOT NULL UNIQUE,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _seedDefaultUsers(Database db) async {
    final users = await db.query('users', limit: 1);

    if (users.isNotEmpty) {
      return;
    }

    await db.insert('users', {
      'username': 'Durgasevak',
      'role': 'viewer',
      'active': 1,
    });

    await db.insert('users', {
      'username': 'Admin',
      'role': 'editor',
      'active': 1,
    });
  }
}
