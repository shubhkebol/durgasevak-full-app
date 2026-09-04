import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class GoogleDriveService {
  static final GoogleDriveService instance =
      GoogleDriveService._internal();

  static const String _webClientId =
      '758439303564-3mg611beiro0ubf31vs6ocetv95llrpd.apps.googleusercontent.com';

  static const String driveFileScope =
      'https://www.googleapis.com/auth/drive.file';

  static const String driveReadonlyScope =
      'https://www.googleapis.com/auth/drive.readonly';

  static const String _driveApi =
      'https://www.googleapis.com/drive/v3';

  static const String _uploadApi =
      'https://www.googleapis.com/upload/drive/v3';

  static const String _folderName = 'Durgasevak';

  static const String _backupFileName =
      'durgasevak_backup.db';

  final GoogleSignIn _googleSignIn =
      GoogleSignIn.instance;

  GoogleSignInAccount? _account;

  bool _initialized = false;

  GoogleDriveService._internal();

  GoogleSignInAccount? get account => _account;

  String? get accountEmail => _account?.email;

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }

    await _googleSignIn.initialize(
      serverClientId: _webClientId,
    );

    _initialized = true;
  }

  Future<GoogleSignInAccount> connect({
    required bool isAdmin,
  }) async {
    await _initialize();

    GoogleSignInAccount? account;

    final lightweightAuthentication =
        _googleSignIn.attemptLightweightAuthentication();

    account ??= await lightweightAuthentication;

    account ??= await _googleSignIn.authenticate();

    _account = account;

    await _authorizeDrive(
      account,
      isAdmin: isAdmin,
    );

    return account;
  }

  Future<String> _getAccessToken({
    required bool isAdmin,
  }) async {
    await _initialize();

    var account = _account;

    account ??= await connect(
      isAdmin: isAdmin,
    );

    final scopes = isAdmin
        ? const <String>[
            driveFileScope,
          ]
        : const <String>[
            driveReadonlyScope,
          ];

    final authorization =
        await account.authorizationClient
            .authorizationForScopes(
      scopes,
    );

    if (authorization != null) {
      return authorization.accessToken;
    }

    final newAuthorization =
        await account.authorizationClient
            .authorizeScopes(
      scopes,
    );

    return newAuthorization.accessToken;
  }

  Future<void> _authorizeDrive(
    GoogleSignInAccount account, {
    required bool isAdmin,
  }) async {
    final scopes = isAdmin
        ? const <String>[
            driveFileScope,
          ]
        : const <String>[
            driveReadonlyScope,
          ];

    final existing =
        await account.authorizationClient
            .authorizationForScopes(
      scopes,
    );

    if (existing != null) {
      return;
    }

    await account.authorizationClient
        .authorizeScopes(scopes);
  }

  Future<String> getOrCreateFolder() async {
    final token = await _getAccessToken(
      isAdmin: true,
    );

    final existingFolder =
        await _findFolder(token);

    if (existingFolder != null) {
      return existingFolder;
    }

    final response = await http.post(
      Uri.parse('$_driveApi/files'),
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer $token',
        HttpHeaders.contentTypeHeader:
            'application/json',
      },
      body: jsonEncode({
        'name': _folderName,
        'mimeType':
            'application/vnd.google-apps.folder',
      }),
    );

    _checkResponse(
      response,
      'Unable to create Durgasevak Drive folder.',
    );

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final id = data['id'] as String?;

    if (id == null || id.isEmpty) {
      throw Exception(
        'Google Drive did not return a folder ID.',
      );
    }

    return id;
  }

  Future<String?> _findFolder(
    String token,
  ) async {
    final query = Uri.encodeQueryComponent(
      "name = '$_folderName' "
      "and mimeType = "
      "'application/vnd.google-apps.folder' "
      "and trashed = false",
    );

    final uri = Uri.parse(
      '$_driveApi/files'
      '?q=$query'
      '&pageSize=20'
      '&fields=files(id,name,modifiedTime)',
    );

    final response = await http.get(
      uri,
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer $token',
      },
    );

    _checkResponse(
      response,
      'Unable to search for Durgasevak folder.',
    );

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final files =
        (data['files'] as List<dynamic>?) ?? [];

    if (files.isEmpty) {
      return null;
    }

    final first =
        files.first as Map<String, dynamic>;

    return first['id'] as String?;
  }

  Future<void> shareFolderWithUser(
    String folderId,
    String email,
  ) async {
    final token = await _getAccessToken(
      isAdmin: true,
    );

    final normalizedEmail =
        email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw Exception(
        'Viewer email address cannot be empty.',
      );
    }

    final response = await http.post(
      Uri.parse(
        '$_driveApi/files/$folderId/permissions'
        '?sendNotificationEmail=true',
      ),
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer $token',
        HttpHeaders.contentTypeHeader:
            'application/json',
      },
      body: jsonEncode({
        'type': 'user',
        'role': 'reader',
        'emailAddress': normalizedEmail,
      }),
    );

    _checkResponse(
      response,
      'Unable to share the Durgasevak folder '
      'with $normalizedEmail.',
    );
  }

  Future<Map<String, dynamic>?>
      getBackupMetadata() async {
    final token = await _getAccessToken(
      isAdmin: false,
    );

    final folderId =
        await _findFolder(token);

    if (folderId == null) {
      return null;
    }

    final query = Uri.encodeQueryComponent(
      "name = '$_backupFileName' "
      "and '$folderId' in parents "
      "and trashed = false",
    );

    final uri = Uri.parse(
      '$_driveApi/files'
      '?q=$query'
      '&pageSize=1'
      '&orderBy=modifiedTime desc'
      '&fields=files(id,name,size,modifiedTime,version)',
    );

    final response = await http.get(
      uri,
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer $token',
      },
    );

    _checkResponse(
      response,
      'Unable to read backup information.',
    );

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final files =
        (data['files'] as List<dynamic>?) ?? [];

    if (files.isEmpty) {
      return null;
    }

    return files.first
        as Map<String, dynamic>;
  }

  Future<String?> findBackupFile() async {
    final metadata =
        await getBackupMetadata();

    return metadata?['id'] as String?;
  }

  Future<String> uploadBackup(
    String backupPath,
    String folderId,
  ) async {
    final token = await _getAccessToken(
      isAdmin: true,
    );

    final existingFile =
        await _findBackupOwnedByApp(
      token,
      folderId,
    );

    if (existingFile != null) {
      await _updateBackup(
        token,
        existingFile,
        backupPath,
      );

      return existingFile;
    }

    return _createBackup(
      token,
      folderId,
      backupPath,
    );
  }

  Future<String?> _findBackupOwnedByApp(
    String token,
    String folderId,
  ) async {
    final query = Uri.encodeQueryComponent(
      "name = '$_backupFileName' "
      "and '$folderId' in parents "
      "and trashed = false",
    );

    final uri = Uri.parse(
      '$_driveApi/files'
      '?q=$query'
      '&pageSize=10'
      '&fields=files(id,name,modifiedTime)',
    );

    final response = await http.get(
      uri,
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer $token',
      },
    );

    _checkResponse(
      response,
      'Unable to locate existing backup.',
    );

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final files =
        (data['files'] as List<dynamic>?) ?? [];

    if (files.isEmpty) {
      return null;
    }

    return (files.first
        as Map<String, dynamic>)['id']
        as String?;
  }

  Future<String> _createBackup(
    String token,
    String folderId,
    String backupPath,
  ) async {
    final fileBytes =
        await File(backupPath).readAsBytes();

    final boundary =
        'DurgasevakBoundary'
        '${DateTime.now().microsecondsSinceEpoch}';

    final metadata = jsonEncode({
      'name': _backupFileName,
      'parents': [folderId],
      'mimeType': 'application/octet-stream',
    });

    final body = <int>[];

    body.addAll(
      utf8.encode(
        '--$boundary\r\n'
        'Content-Type: application/json; '
        'charset=UTF-8\r\n'
        '\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/octet-stream\r\n'
        '\r\n',
      ),
    );

    body.addAll(fileBytes);

    body.addAll(
      utf8.encode(
        '\r\n--$boundary--\r\n',
      ),
    );

    final response = await http.post(
      Uri.parse(
        '$_uploadApi/files'
        '?uploadType=multipart'
        '&fields=id,name,modifiedTime',
      ),
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer $token',
        HttpHeaders.contentTypeHeader:
            'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    _checkResponse(
      response,
      'Unable to upload Durgasevak backup.',
    );

    final data =
        jsonDecode(response.body)
            as Map<String, dynamic>;

    final id = data['id'] as String?;

    if (id == null || id.isEmpty) {
      throw Exception(
        'Google Drive did not return backup file ID.',
      );
    }

    return id;
  }

  Future<void> _updateBackup(
    String token,
    String fileId,
    String backupPath,
  ) async {
    final fileBytes =
        await File(backupPath).readAsBytes();

    final response = await http.patch(
      Uri.parse(
        '$_uploadApi/files/$fileId'
        '?uploadType=media'
        '&fields=id,name,modifiedTime',
      ),
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer $token',
        HttpHeaders.contentTypeHeader:
            'application/octet-stream',
      },
      body: fileBytes,
    );

    _checkResponse(
      response,
      'Unable to update Durgasevak backup.',
    );
  }

  Future<String> downloadBackup(
    String fileId,
    String destinationPath,
  ) async {
    final token = await _getAccessToken(
      isAdmin: false,
    );

    final response = await http.get(
      Uri.parse(
        '$_driveApi/files/$fileId?alt=media',
      ),
      headers: {
        HttpHeaders.authorizationHeader:
            'Bearer $token',
      },
    );

    _checkResponse(
      response,
      'Unable to download Durgasevak backup.',
    );

    final file = File(destinationPath);

    await file.writeAsBytes(
      response.bodyBytes,
      flush: true,
    );

    return destinationPath;
  }

  Future<void> disconnect() async {
    _account = null;
  }

  void _checkResponse(
    http.Response response,
    String message,
  ) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return;
    }

    String detail = '';

    try {
      final decoded =
          jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];

        if (error is Map<String, dynamic>) {
          detail =
              error['message']?.toString() ?? '';
        }
      }
    } catch (_) {
      detail = response.body;
    }

    if (detail.isNotEmpty) {
      throw Exception(
        '$message\n\n'
        'Google response: $detail '
        '(${response.statusCode})',
      );
    }

    throw Exception(
      '$message '
      '(${response.statusCode}).',
    );
  }
}