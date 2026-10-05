import 'package:sqflite/sqflite.dart';

import '../database/database_service.dart';
import '../models/admin_contact.dart';

class AdminContactRepository {
  final DatabaseService _databaseService = DatabaseService.instance;

  static const List<AdminContact> defaultAdminContacts = [
    AdminContact(
      name: 'Aniket Patil',
      post: 'मुख्य ॲडमिन',
      mobile: '7276685220',
      isPrimary: true,
    ),
    AdminContact(
      name: 'Nitesh Juikar',
      post: 'सह-ॲडमिन',
      mobile: '8550951707',
      isPrimary: false,
    ),
    AdminContact(
      name: 'Shubham',
      post: 'ॲडमिन',
      mobile: '8390161840',
      isPrimary: false,
    ),
  ];

  Future<List<AdminContact>> getAdminContacts() async {
    try {
      final db = await _databaseService.database;

      // Purge old dummy contacts if present
      await db.delete(
        'admin_contacts',
        where:
            "mobile IN ('9822012345', '9822054321', '9822098765') "
            "OR name IN ('रोहन सावंत', 'अमित देशमुख', 'सचिन शिंदे')",
      );

      // Ensure Shubham testing contact is present in database
      final hasShubham = await db.query(
        'admin_contacts',
        where: "mobile = ?",
        whereArgs: ['8390161840'],
        limit: 1,
      );
      if (hasShubham.isEmpty) {
        await db.insert('admin_contacts', {
          'name': 'Shubham',
          'post': 'ॲडमिन',
          'mobile': '8390161840',
          'is_primary': 0,
        });
      }

      final results = await db.query(
        'admin_contacts',
        orderBy: 'is_primary DESC, id ASC',
      );

      if (results.isEmpty) {
        // Seed default contacts if empty
        await seedDefaultContacts(db);
        final seeded = await db.query(
          'admin_contacts',
          orderBy: 'is_primary DESC, id ASC',
        );
        return seeded.map((map) => AdminContact.fromMap(map)).toList();
      }

      return results.map((map) => AdminContact.fromMap(map)).toList();
    } catch (_) {
      // Return default contacts if table doesn't exist yet
      return defaultAdminContacts;
    }
  }

  Future<void> seedDefaultContacts(Database db) async {
    for (final contact in defaultAdminContacts) {
      await db.insert(
        'admin_contacts',
        contact.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<int> addAdminContact(AdminContact contact) async {
    final db = await _databaseService.database;
    return await db.insert(
      'admin_contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateAdminContact(AdminContact contact) async {
    if (contact.id == null) return 0;
    final db = await _databaseService.database;
    return await db.update(
      'admin_contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<int> deleteAdminContact(int id) async {
    final db = await _databaseService.database;
    return await db.delete('admin_contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setPrimaryAdmin(int id) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.update('admin_contacts', {'is_primary': 0});
      await txn.update(
        'admin_contacts',
        {'is_primary': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
