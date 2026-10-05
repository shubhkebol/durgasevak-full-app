import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

import '../services/auth_service.dart';
import '../services/backend_sync_service.dart';
import '../services/database_backup_service.dart';
import '../services/google_drive_service.dart';
import '../services/sync_metadata_service.dart';
import '../widgets/admin_contacts_dialog.dart';
import '../widgets/admin_selection_sheet.dart';
import '../widgets/app_background.dart';
import '../widgets/whatsapp_icon.dart';

class DataSyncScreen extends StatefulWidget {
  final AuthUser user;
  final String? incomingBackupPath;

  const DataSyncScreen({
    super.key,
    required this.user,
    this.incomingBackupPath,
  });

  @override
  State<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  final DatabaseBackupService _backupService = DatabaseBackupService.instance;
  final SyncMetadataService _metadataService = SyncMetadataService.instance;
  final GoogleDriveService _driveService = GoogleDriveService.instance;
  final TextEditingController _viewerEmailController = TextEditingController();

  bool _busy = false;
  bool _automaticImportRunning = false;

  String? _lastExported;
  String? _lastImported;
  String? _localDataVersion;
  String? _driveAccountEmail;

  String? _incomingPath;
  String? _incomingVersion;
  bool? _incomingIsNewer;

  bool get _isAdmin => widget.user.isAdmin;

  @override
  void initState() {
    super.initState();

    _incomingPath = widget.incomingBackupPath;

    _loadMetadata().then((_) async {
      if (_incomingPath != null && !_isAdmin) {
        await _handleAutomaticImport(_incomingPath!);
      }
    });
  }

  @override
  void dispose() {
    _viewerEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final exported = await _metadataService.get('last_exported_at');
    final imported = await _metadataService.get('last_imported_at');
    final localVersion = await _metadataService.get('local_data_version');
    final savedEmail = await _metadataService.get('viewer_email');
    final savedAdminGmail = await _metadataService.get('official_admin_gmail');

    if (!mounted) return;

    setState(() {
      _lastExported = exported;
      _lastImported = imported;
      _localDataVersion = localVersion;
      if (savedEmail != null && _viewerEmailController.text.isEmpty) {
        _viewerEmailController.text = savedEmail;
      }
      if (_driveService.accountEmail != null) {
        _driveAccountEmail = _driveService.accountEmail;
      } else if (savedAdminGmail != null && savedAdminGmail.isNotEmpty) {
        _driveAccountEmail = savedAdminGmail;
      }
    });
  }

  Future<void> _exportAndShareData() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    String? backupPath;

    try {
      backupPath = await _backupService.createBackup();

      final now = DateTime.now().toIso8601String();

      await _metadataService.set('last_exported_at', now);

      final version = await _backupService.getBackupDataVersion(backupPath);

      if (version != null) {
        await _metadataService.set('local_data_version', version);
      }

      await _loadMetadata();

      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(backupPath)],
          subject: 'दुर्गसेवक डेटा बॅकअप',
          text:
              'दुर्गसेवक डेटा बॅकअप. '
              'नवीनतम डेटा आयात करण्यासाठी ही फाइल '
              'व्ह्यूअर फोनवर उघडा.',
        ),
      );

      if (!mounted) return;

      _showMessage('बॅकअप यशस्वीरीत्या तयार केला.');
    } catch (e) {
      if (!mounted) return;

      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (backupPath != null) {
        final file = File(backupPath);

        if (await file.exists()) {
          await file.delete();
        }
      }

      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _uploadToCloud() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    String? backupPath;

    try {
      backupPath = await _backupService.createBackup();

      final now = DateTime.now().toIso8601String();
      await _metadataService.set('last_exported_at', now);
      final version = await _backupService.getBackupDataVersion(backupPath);
      if (version != null) {
        await _metadataService.set('local_data_version', version);
      }
      await _loadMetadata();

      if (!mounted) return;
      _showMessage('बॅकअप क्लाउडवर अपलोड करत आहे...');

      final syncService = BackendSyncService.instance;
      // Use Admin credentials to get token
      final token = await syncService.login('Admin', 'Chatrapati');
      await syncService.uploadBackup(backupPath, token);

      if (!mounted) return;
      _showMessage('बॅकअप क्लाउडवर यशस्वीरीत्या अपलोड केला.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (backupPath != null) {
        final file = File(backupPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _fetchFromCloud() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      _showMessage('क्लाउडवरून बॅकअप मिळवत आहे...');

      final syncService = BackendSyncService.instance;
      // Viewers can use the default viewer account
      final token = await syncService.login('Durgasevak', 'Durgasevak');

      final tempDirectory = Directory.systemTemp;
      final downloadedPath = await syncService.downloadLatestBackup(
        tempDirectory.path,
        token,
      );

      if (!mounted) return;

      await _inspectIncomingBackup(downloadedPath);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _uploadToGoogleDrive() async {
    if (_busy) return;
    setState(() => _busy = true);

    String? backupPath;
    try {
      _showMessage('गुगल ड्राइव्हशी कनेक्ट करत आहे...');
      final account = await _driveService.connect(isAdmin: true);
      await _metadataService.set('official_admin_gmail', account.email);
      setState(() => _driveAccountEmail = account.email);

      _showMessage('बॅकअप तयार करत आहे...');
      backupPath = await _backupService.createBackup();

      final now = DateTime.now().toIso8601String();
      await _metadataService.set('last_exported_at', now);
      final version = await _backupService.getBackupDataVersion(backupPath);
      if (version != null) {
        await _metadataService.set('local_data_version', version);
      }
      await _loadMetadata();

      if (!mounted) return;
      _showMessage('गुगल ड्राइव्हवर बॅकअप सेव्ह करत आहे...');

      final folderId = await _driveService.getOrCreateFolder();
      await _driveService.uploadBackup(backupPath, folderId);

      if (!mounted) return;
      _showMessage(
        'बॅकअप गुगल ड्राइव्हवर सुरक्षितपणे सेव्ह झाला! (खाते: ${account.email})',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (backupPath != null) {
        final file = File(backupPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _switchGoogleAccount() async {
    await _driveService.disconnect();
    await _metadataService.set('official_admin_gmail', '');
    if (mounted) {
      setState(() {
        _driveAccountEmail = null;
      });
      _showMessage('खाते बदलण्यासाठी कृपया नवीन अधिकृत Google खाते निवडा.');
    }
    await _uploadToGoogleDrive();
  }

  Future<void> _grantViewerPermission() async {
    if (_busy) return;
    final emailController = TextEditingController();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: Colors.blue),
            SizedBox(width: 8),
            Text('व्ह्यूअर Gmail परवानगी द्या', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'सदस्याचा Gmail पत्ता प्रविष्ट करा ज्याला गुगल ड्राइव्ह बॅकअप पाहण्याची परवानगी द्यायची आहे:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'सदस्याचा Gmail (उदा. member@gmail.com)',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(null),
            child: const Text('रद्द करा'),
          ),
          FilledButton(
            onPressed: () {
              final text = emailController.text.trim();
              if (text.isEmpty || !text.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('कृपया वैध Gmail पत्ता प्रविष्ट करा'),
                  ),
                );
                return;
              }
              Navigator.of(dialogCtx).pop(text);
            },
            child: const Text('परवानगी द्या'),
          ),
        ],
      ),
    );

    if (email == null) return;

    setState(() => _busy = true);
    try {
      _showMessage('गुगल ड्राइव्हशी कनेक्ट करत आहे...');
      await _driveService.connect(isAdmin: true);

      _showMessage('$email साठी परवानगी जोडत आहे...');
      final folderId = await _driveService.getOrCreateFolder();
      await _driveService.shareFolderWithUser(folderId, email);

      if (!mounted) return;
      _showMessage(
        '$email या खात्याला गुगल ड्राइव्ह पाहण्याची परवानगी यशस्वीरीत्या दिली!',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _manageAdminContacts() {
    AdminContactsDialog.show(context);
  }

  Future<void> _fetchFromGoogleDrive() async {
    if (_busy) return;

    final viewerEmail = _viewerEmailController.text.trim();
    if (viewerEmail.isNotEmpty) {
      await _metadataService.set('viewer_email', viewerEmail);
    }

    setState(() => _busy = true);

    try {
      _showMessage('गुगल ड्राइव्हशी कनेक्ट करत आहे...');
      final account = await _driveService.connect(isAdmin: false);
      setState(() => _driveAccountEmail = account.email);

      _showMessage('गुगल ड्राइव्हवर बॅकअप शोधत आहे...');
      final fileId = await _driveService.findBackupFile();

      if (fileId == null) {
        throw Exception(
          'दुर्गसेवक बॅकअप फाइल सापडली नाही. '
          'कृपया ॲडमिनकडे तुमच्या ईमेल ($viewerEmail) साठी परवानगी मागा.',
        );
      }

      final tempDirectory = Directory.systemTemp;
      final targetPath = path.join(
        tempDirectory.path,
        'durgasevak_gdrive_${DateTime.now().millisecondsSinceEpoch}.db',
      );

      _showMessage('बॅकअप डाऊनलोड करत आहे...');
      final downloadedPath = await _driveService.downloadBackup(
        fileId,
        targetPath,
      );

      if (!mounted) return;
      await _inspectIncomingBackup(downloadedPath);
    } catch (e) {
      if (!mounted) return;
      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _requestAdminApproval() {
    final email = _viewerEmailController.text.trim();
    if (email.isNotEmpty) {
      _metadataService.set('viewer_email', email);
    }
    AdminSelectionSheet.show(
      context,
      viewerEmail: email,
      isLoginScreen: false,
    );
  }

  Future<void> _pickBackupFile() async {
    if (_busy) return;

    try {
      final PlatformFile? selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['db', 'durgasevak'],
      );

      if (selected == null) {
        return;
      }

      String? selectedPath = selected.path;

      if (selectedPath == null || selectedPath.trim().isEmpty) {
        final bytes = await selected.readAsBytes();

        final tempDirectory = Directory.systemTemp;

        final tempFile = File(
          path.join(
            tempDirectory.path,
            'durgasevak_import_'
            '${DateTime.now().millisecondsSinceEpoch}.db',
          ),
        );

        await tempFile.writeAsBytes(bytes, flush: true);

        selectedPath = tempFile.path;
      }

      await _inspectIncomingBackup(selectedPath);
    } catch (e) {
      if (!mounted) return;

      _showMessage(_cleanError(e), isError: true);
    }
  }

  Future<void> _inspectIncomingBackup(String backupPath) async {
    try {
      final file = File(backupPath);

      if (!await file.exists()) {
        throw Exception('निवडलेली बॅकअप फाइल आढळली नाही.');
      }

      await _backupService.validateBackup(backupPath);

      final incomingVersion = await _backupService.getBackupDataVersion(
        backupPath,
      );

      final localDatabasePath = await _backupService.getDatabasePath();

      final localVersion = await _backupService.getBackupDataVersion(
        localDatabasePath,
      );

      DateTime? incomingDate;

      if (incomingVersion != null) {
        incomingDate = DateTime.tryParse(incomingVersion);
      }

      final localDate = localVersion == null
          ? null
          : DateTime.tryParse(localVersion);

      bool? isNewer;

      if (incomingDate != null && localDate != null) {
        isNewer = incomingDate.isAfter(localDate);
      } else if (incomingDate != null && localDate == null) {
        isNewer = true;
      }

      if (!mounted) return;

      setState(() {
        _incomingPath = backupPath;
        _incomingVersion = incomingVersion;
        _incomingIsNewer = isNewer;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _incomingPath = backupPath;
        _incomingVersion = null;
        _incomingIsNewer = false;
      });

      _showMessage(_cleanError(e), isError: true);
    }
  }

  Future<void> _handleAutomaticImport(String backupPath) async {
    if (_automaticImportRunning || _busy || _isAdmin) {
      return;
    }

    _automaticImportRunning = true;

    try {
      final file = File(backupPath);

      if (!await file.exists()) {
        throw Exception('प्राप्त झालेली दुर्गसेवक बॅकअप फाइल आढळली नाही.');
      }

      final incomingVersion = await _backupService.validateBackup(backupPath);

      final localDatabasePath = await _backupService.getDatabasePath();

      final localVersion = await _backupService.getBackupDataVersion(
        localDatabasePath,
      );

      final incomingDate = DateTime.tryParse(incomingVersion);

      final localDate = localVersion == null
          ? null
          : DateTime.tryParse(localVersion);

      if (incomingDate == null) {
        throw Exception('बॅकअप डेटा व्हर्जन अवैध आहे.');
      }

      final isNewer = localDate == null || incomingDate.isAfter(localDate);

      if (!isNewer) {
        if (!mounted) return;

        _showMessage('हा बॅकअप सध्याच्या डेटापेक्षा नवीन नाही.', isError: true);

        return;
      }

      if (!mounted) return;

      setState(() {
        _busy = true;
        _incomingPath = backupPath;
        _incomingVersion = incomingVersion;
        _incomingIsNewer = true;
      });

      await _backupService.restoreBackup(backupPath);

      final importedVersion = await _backupService.getBackupDataVersion(
        backupPath,
      );

      final now = DateTime.now().toIso8601String();

      await _metadataService.set('last_imported_at', now);

      if (importedVersion != null) {
        await _metadataService.set('local_data_version', importedVersion);
      }

      if (!mounted) return;

      _showMessage('नवीनतम डेटा यशस्वीरीत्या आयात केला.');

      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(_cleanError(e), isError: true);
    } finally {
      _automaticImportRunning = false;

      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _importSelectedBackup() async {
    if (_busy) return;

    final backupPath = _incomingPath;

    if (backupPath == null) {
      await _pickBackupFile();
      return;
    }

    if (_incomingIsNewer != true) {
      _showMessage('हा बॅकअप सध्याच्या डेटापेक्षा नवीन नाही.', isError: true);

      return;
    }

    final confirmed = await _confirmImport();

    if (!confirmed) return;

    setState(() {
      _busy = true;
    });

    try {
      await _backupService.restoreBackup(backupPath);

      final importedVersion = await _backupService.getBackupDataVersion(
        backupPath,
      );

      final now = DateTime.now().toIso8601String();

      await _metadataService.set('last_imported_at', now);

      if (importedVersion != null) {
        await _metadataService.set('local_data_version', importedVersion);
      }

      await _loadMetadata();

      if (!mounted) return;

      setState(() {
        _incomingPath = null;
        _incomingVersion = null;
        _incomingIsNewer = null;
      });

      _showMessage(
        'नवीनतम डेटा यशस्वीरीत्या आयात केला. '
        'कृपया मुख्यपृष्ठावर परत जा.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(_cleanError(e), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<bool> _confirmImport() async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('डेटा आयात करायचा?'),
          content: const Text(
            'डेटा आयात केल्याने सध्याचा सर्व स्थानिक '
            'दुर्गसेवक डेटा निवडलेल्या ॲडमिन '
            'बॅकअपसह बदलला जाईल.\n\n'
            'तुम्ही योग्य बॅकअप फाइल निवडल्याची '
            'खात्री करा.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('रद्द करा'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('आयात करा'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  String _cleanError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text;
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'उपलब्ध नाही';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    final local = date.toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(local.day)}/'
        '${two(local.month)}/'
        '${local.year} '
        '${two(local.hour)}:'
        '${two(local.minute)}';
  }

  String _fileName(String? filePath) {
    if (filePath == null || filePath.isEmpty) {
      return 'कोणताही बॅकअप निवडलेला नाही';
    }

    return path.basename(filePath);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('डेटा सिंक')),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadMetadata,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                if (_isAdmin) _buildAdminSection() else _buildViewerSection(),
                const SizedBox(height: 16),
                if (!_isAdmin && _incomingPath != null)
                  _buildIncomingBackupCard(),
                if (!_isAdmin && _incomingPath != null)
                  const SizedBox(height: 16),
                _buildHistoryCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Icon(
                _isAdmin ? Icons.admin_panel_settings : Icons.visibility,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isAdmin ? 'ॲडमिन डेटा सिंक' : 'व्ह्यूअर डेटा सिंक',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isAdmin
                        ? 'नवीनतम स्थानिक डेटा एक्सपोर्ट करा आणि व्ह्यूअरसोबत शेअर करा.'
                        : 'ॲडमिनकडून प्राप्त झालेला नवीनतम डेटा आयात करा.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.orange, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_to_drive,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'गुगल ड्राइव्ह मास्टर बॅकअप',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'कायमस्वरूपी मोफत • ३० दिवसांचे बंधन नाही',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _driveAccountEmail != null
                        ? Colors.green.withAlpha(25)
                        : Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _driveAccountEmail != null
                          ? Colors.green.withAlpha(80)
                          : Colors.orange.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _driveAccountEmail != null
                            ? Icons.check_circle
                            : Icons.account_circle_outlined,
                        color: _driveAccountEmail != null
                            ? Colors.greenAccent
                            : Colors.orange,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'अधिकृत गुगल खाते (Official Gmail)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _driveAccountEmail ?? 'अद्याप खाते जोडलेले नाही',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _driveAccountEmail != null
                                    ? Colors.white
                                    : Colors.orangeAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_driveAccountEmail != null)
                        TextButton(
                          onPressed: _busy ? null : _switchGoogleAccount,
                          child: const Text('बदला'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _uploadToGoogleDrive,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text(
                    'गुगल ड्राइव्हवर बॅकअप सेव्ह करा',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _grantViewerPermission,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('व्ह्यूअर Gmail परवानगी जोडा'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _manageAdminContacts,
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('अधिकृत ॲडमिन संपर्क यादी (२-३ ॲडमिन)'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'स्थानिक बॅकअप व शेअरिंग',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'डेटाबेस थेट फोनवरून व्हॉट्सॲपवर पाठवा किंवा सेव्ह करा.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _exportAndShareData,
                  icon: const Icon(Icons.ios_share),
                  label: const Text(
                    'डेटा एक्सपोर्ट व शेअर करा (WhatsApp / Drive)',
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _busy ? null : _uploadToCloud,
                  icon: const Icon(Icons.cloud_sync, size: 18),
                  label: const Text('पर्यायी Render क्लाउडवर अपलोड करा'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.blueAccent, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_download,
                        color: Colors.blueAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'गुगल ड्राइव्हवरून डेटा सिंक करा',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ॲडमिनच्या अधिकृत गुगल ड्राइव्हवरून थेट डेटा मिळवा',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _viewerEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'तुमचा Gmail पत्ता (नोंदणीकृत)',
                    hintText: 'उदा. member@gmail.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _busy ? null : _fetchFromGoogleDrive,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.sync),
                  label: const Text(
                    'गुगल ड्राइव्हवरून डेटा सिंक करा',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _requestAdminApproval,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const WhatsAppIcon(size: 20),
                  label: const Text(
                    'ॲडमिनकडे परवानगी मागा (WhatsApp)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'स्थानिक फाइल किंवा पर्यायी क्लाउड',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickBackupFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('स्थानिक बॅकअप फाइल निवडा (.db)'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _busy ? null : _fetchFromCloud,
                  icon: const Icon(Icons.cloud_sync, size: 18),
                  label: const Text('पर्यायी Render क्लाउडवरून प्राप्त करा'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingBackupCard() {
    final newer = _incomingIsNewer == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'निवडलेला बॅकअप',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                newer
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
              ),
              title: Text(_fileName(_incomingPath)),
              subtitle: Text(
                _incomingVersion == null
                    ? 'बॅकअप आवृत्ती वाचता आली नाही'
                    : 'बॅकअप आवृत्ती: '
                          '${_formatDate(_incomingVersion)}',
              ),
            ),
            const SizedBox(height: 8),
            if (_incomingIsNewer == true)
              const Text(
                'नवीन ॲडमिन बॅकअप उपलब्ध आहे.',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const Text(
                'हा बॅकअप आयात केला जाऊ शकत नाही कारण तो सध्याच्या डेटापेक्षा नवीन नाही.',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 16),
            if (_incomingIsNewer == true)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _importSelectedBackup,
                  icon: const Icon(Icons.download_done),
                  label: const Text('नवीनतम डेटा आयात करा'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'डेटा इतिहास',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.update),
              title: const Text('सध्याची डेटा आवृत्ती'),
              subtitle: Text(_formatDate(_localDataVersion)),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_outlined),
              title: const Text('शेवटचे एक्सपोर्ट'),
              subtitle: Text(_formatDate(_lastExported)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download_outlined),
              title: const Text('शेवटचे आयात'),
              subtitle: Text(_formatDate(_lastImported)),
            ),
          ],
        ),
      ),
    );
  }
}
