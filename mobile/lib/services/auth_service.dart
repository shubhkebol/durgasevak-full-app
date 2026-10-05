import '../database/database_service.dart';

class AuthUser {
  final int id;
  final String username;
  final String role;

  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
  });

  bool get isAdmin => role == 'editor';
  bool get isViewer => role == 'viewer';
}

class AuthService {
  final DatabaseService _databaseService = DatabaseService.instance;

  Future<AuthUser?> login(String username, String password) async {
    // Temporary V1 authentication.
    //
    // Passwords will be moved to a proper local credential
    // mechanism before production release.

    const passwords = {
      'Durgasevak': 'Durgasevak',
      'Admin': 'Chatrapati',
    };

    if (passwords[username] != password) {
      return null;
    }

    final db = await _databaseService.database;

    // Migrate old Admin@1 to Admin if needed
    if (username == 'Admin') {
      await db.update(
        'users',
        {'username': 'Admin'},
        where: 'username = ?',
        whereArgs: ['Admin@1'],
      );
    }

    final results = await db.query(
      'users',
      where: 'username = ? AND active = 1',
      whereArgs: [username],
      limit: 1,
    );

    if (results.isEmpty) {
      // Auto-insert Admin if role is editor and password matched
      if (username == 'Admin') {
        final id = await db.insert('users', {
          'username': username,
          'role': 'editor',
          'active': 1,
        });
        return AuthUser(id: id, username: username, role: 'editor');
      }
      return null;
    }

    final row = results.first;

    return AuthUser(
      id: row['id'] as int,
      username: row['username'] as String,
      role: row['role'] as String,
    );
  }
}
