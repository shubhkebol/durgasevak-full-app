import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

import '../services/auth_service.dart';
import '../services/backend_sync_service.dart';
import '../services/database_backup_service.dart';
import '../services/sync_metadata_service.dart';
import '../widgets/app_background.dart';

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

  bool _busy = false;
  bool _automaticImportRunning = false;

  String? _lastExported;
  String? _lastImported;
  String? _localDataVersion;

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

  Future<void> _loadMetadata() async {
    final exported = await _metadataService.get('last_exported_at');

    final imported = await _metadataService.get('last_imported_at');

    final localVersion = await _metadataService.get('local_data_version');

    if (!mounted) return;

    setState(() {
      _lastExported = exported;
      _lastImported = imported;
      _localDataVersion = localVersion;
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
          subject: 'Durgasevak Data Backup',
          text:
              'Durgasevak data backup. '
              'Open this file on the Viewer phone '
              'to import the latest data.',
        ),
      );

      if (!mounted) return;

      _showMessage('Backup created successfully.');
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
      _showMessage('Uploading backup to cloud...');

      final syncService = BackendSyncService.instance;
      // Use Admin credentials to get token
      final token = await syncService.login('Admin', 'Chatrapati');
      await syncService.uploadBackup(backupPath, token);

      if (!mounted) return;
      _showMessage('Backup uploaded to cloud successfully.');
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
      _showMessage('Fetching backup from cloud...');

      final syncService = BackendSyncService.instance;
      // Viewers can use the default viewer account
      final token = await syncService.login('Durgasevak', 'Durgasevak');
      
      final tempDirectory = Directory.systemTemp;
      final downloadedPath = await syncService.downloadLatestBackup(tempDirectory.path, token);

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
        throw Exception('Selected backup file was not found.');
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
        throw Exception(
          'The received Durgasevak backup file '
          'could not be found.',
        );
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
        throw Exception('The backup data version is invalid.');
      }

      final isNewer = localDate == null || incomingDate.isAfter(localDate);

      if (!isNewer) {
        if (!mounted) return;

        _showMessage(
          'This backup is not newer than the '
          'current Viewer data.',
          isError: true,
        );

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

      _showMessage('Latest Admin data imported successfully.');

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
      _showMessage(
        'This backup is not newer than the '
        'current data.',
        isError: true,
      );

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
        'Latest data imported successfully. '
        'Please return to Dashboard.',
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
          title: const Text('Import Data?'),
          content: const Text(
            'Importing will replace all current '
            'local Durgasevak data with the '
            'selected Admin backup.\n\n'
            'Make sure you selected the correct '
            'backup file.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Import'),
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
      return 'Not available';
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
      return 'No backup selected';
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
      appBar: AppBar(title: const Text('Data Sync')),
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
                    _isAdmin ? 'Admin Data Sync' : 'Viewer Data Sync',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isAdmin
                        ? 'Export the latest local data '
                              'and share it with the Viewer.'
                        : 'Import the latest Admin data '
                              'received from the Admin.',
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Admin',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a complete backup of the '
              'current Durgasevak database and '
              'share it with the Viewer or upload it to Cloud.',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _uploadToCloud,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload to Cloud'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _exportAndShareData,
              icon: const Icon(Icons.ios_share),
              label: const Text('Export & Share Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Viewer',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fetch latest backup from Cloud, or select a backup manually '
              'if it was not opened directly from '
              'another app.',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _fetchFromCloud,
              icon: const Icon(Icons.cloud_download),
              label: const Text('Fetch from Cloud'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickBackupFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Select Backup File'),
            ),
          ],
        ),
      ),
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
              'Selected Backup',
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
                    ? 'Unable to read backup version'
                    : 'Backup version: '
                          '${_formatDate(_incomingVersion)}',
              ),
            ),
            const SizedBox(height: 8),
            if (_incomingIsNewer == true)
              const Text(
                'A newer Admin backup is available.',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const Text(
                'This backup cannot be imported '
                'because it is not newer than '
                'the current data.',
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
                  label: const Text('Import Latest Data'),
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
              'Data History',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.update),
              title: const Text('Current data version'),
              subtitle: Text(_formatDate(_localDataVersion)),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Last exported'),
              subtitle: Text(_formatDate(_lastExported)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download_outlined),
              title: const Text('Last imported'),
              subtitle: Text(_formatDate(_lastImported)),
            ),
          ],
        ),
      ),
    );
  }
}
