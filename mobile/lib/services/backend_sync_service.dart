import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class BackendSyncService {
  static final BackendSyncService instance = BackendSyncService._internal();

  // Connect to the permanently hosted cloud backend!
  static const String baseUrl = 'https://durgasevak-backend.onrender.com';

  BackendSyncService._internal();

  Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  Future<void> uploadBackup(String backupPath, String token) async {
    final file = File(backupPath);
    if (!await file.exists()) {
      throw Exception('Backup file not found.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/backup/import'),
    );
    
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: 'durgasevak_backup.db',
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Upload failed: ${response.body}');
    }
  }

  Future<String> downloadLatestBackup(String destinationDir, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/backup/download_latest'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final destFile = File(path.join(destinationDir, 'durgasevak_downloaded.db'));
      await destFile.writeAsBytes(response.bodyBytes);
      return destFile.path;
    } else {
      throw Exception('Download failed: ${response.body}');
    }
  }
}
