import 'dart:io';

import 'package:flutter/material.dart';

// import '../database/database_service.dart';
import '../services/auth_service.dart';
import '../services/database_backup_service.dart';
import '../services/google_drive_service.dart';
import '../services/sync_metadata_service.dart';

class DataSyncScreen extends StatefulWidget {
  final AuthUser user;

  const DataSyncScreen({
    super.key,
    required this.user,
  });

  @override
  State<DataSyncScreen> createState() =>
      _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  final GoogleDriveService _driveService =
      GoogleDriveService.instance;

  final DatabaseBackupService _backupService =
      DatabaseBackupService.instance;

  final SyncMetadataService _metadataService =
      SyncMetadataService.instance;

  final TextEditingController _viewerEmailController =
      TextEditingController();

  bool _busy = false;

  String? _googleEmail;
  String? _lastUploaded;
  String? _lastDownloaded;
  String? _driveModifiedTime;

  bool get _isAdmin => widget.user.isAdmin;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    _viewerEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    final email = await _metadataService.get(
      'google_account',
    );

    final uploaded = await _metadataService.get(
      'last_uploaded_at',
    );

    final downloaded = await _metadataService.get(
      'last_downloaded_at',
    );

    final driveModified = await _metadataService.get(
      'drive_modified_time',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _googleEmail = email;
      _lastUploaded = uploaded;
      _lastDownloaded = downloaded;
      _driveModifiedTime = driveModified;
    });
  }

  Future<void> _connectGoogleDrive() async {
    await _runBusy(() async {
      final account = await _driveService.connect(
        isAdmin: _isAdmin,
      );

      await _metadataService.set(
        'google_account',
        account.email,
      );

      if (mounted) {
        setState(() {
          _googleEmail = account.email;
        });
      }

      _showMessage(
        'Google Drive connected as ${account.email}.',
      );
    });
  }

  Future<void> _updateOnGoogleDrive() async {
    await _runBusy(() async {
      final account = await _driveService.connect(
        isAdmin: true,
      );

      await _metadataService.set(
        'google_account',
        account.email,
      );

      final folderId =
          await _driveService.getOrCreateFolder();

      await _metadataService.set(
        'drive_folder_id',
        folderId,
      );

      final backupPath =
          await _backupService.createBackup();

      try {
        final fileId =
            await _driveService.uploadBackup(
          backupPath,
          folderId,
        );

        await _metadataService.set(
          'drive_backup_file_id',
          fileId,
        );

        final now =
            DateTime.now().toIso8601String();

        await _metadataService.set(
          'last_uploaded_at',
          now,
        );

        await _metadataService.set(
          'local_data_version',
          now,
        );

        await _loadMetadata();

        _showMessage(
          'Data updated on Google Drive successfully.',
        );
      } finally {
        final file = File(backupPath);

        if (await file.exists()) {
          await file.delete();
        }
      }
    });
  }

  Future<void> _shareFolder() async {
    final email = _viewerEmailController.text
        .trim()
        .toLowerCase();

    if (email.isEmpty) {
      _showMessage(
        'Enter a viewer Gmail address first.',
        isError: true,
      );
      return;
    }

    if (!email.endsWith('@gmail.com')) {
      _showMessage(
        'Please enter a valid @gmail.com address.',
        isError: true,
      );
      return;
    }

    await _runBusy(() async {
      final folderId =
          await _driveService.getOrCreateFolder();

      await _metadataService.set(
        'drive_folder_id',
        folderId,
      );

      await _driveService.shareFolderWithUser(
        folderId,
        email,
      );

      _viewerEmailController.clear();

      _showMessage(
        'Durgasevak folder shared with $email as Viewer.',
      );
    });
  }

  Future<void> _fetchLatestData() async {
    await _runBusy(() async {
      final account = await _driveService.connect(
        isAdmin: false,
      );

      await _metadataService.set(
        'google_account',
        account.email,
      );

      final metadata =
          await _driveService.getBackupMetadata();

      if (metadata == null) {
        _showMessage(
          'No Durgasevak backup was found on Google Drive.',
          isError: true,
        );
        return;
      }

      final fileId = metadata['id'] as String?;

      final modifiedTime =
          metadata['modifiedTime'] as String?;

      if (fileId == null || fileId.isEmpty) {
        throw Exception(
          'Google Drive returned an invalid backup file.',
        );
      }

      final localVersion =
          await _metadataService.get(
        'local_data_version',
      );

      if (modifiedTime != null &&
          localVersion != null) {
        final remote =
            DateTime.tryParse(modifiedTime);

        final local =
            DateTime.tryParse(localVersion);

        if (remote != null &&
            local != null &&
            !remote.isAfter(local)) {
          _showMessage(
            'Your local data is already up to date.',
          );
          return;
        }
      }

      final databasePath =
          await _backupService.getDatabasePath();

      final downloadPath =
          '$databasePath.download';

      try {
        await _driveService.downloadBackup(
          fileId,
          downloadPath,
        );

        await _backupService.restoreBackup(
          downloadPath,
        );

        final now =
            DateTime.now().toIso8601String();

        await _metadataService.set(
          'last_downloaded_at',
          now,
        );

        if (modifiedTime != null) {
          await _metadataService.set(
            'drive_modified_time',
            modifiedTime,
          );

          await _metadataService.set(
            'local_data_version',
            modifiedTime,
          );
        } else {
          await _metadataService.set(
            'local_data_version',
            now,
          );
        }

        await _loadMetadata();

        _showMessage(
          'Latest data fetched successfully.',
        );
      } finally {
        final downloaded = File(downloadPath);

        if (await downloaded.exists()) {
          await downloaded.delete();
        }
      }
    });
  }

  Future<void> _runBusy(
    Future<void> Function() action,
  ) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await action();
    } catch (e) {
      if (mounted) {
        _showMessage(
          _cleanError(e),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _cleanError(Object error) {
    final text = error.toString();

    if (text.startsWith('Exception: ')) {
      return text.substring(
        'Exception: '.length,
      );
    }

    return text;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red : null,
        ),
      );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Not available';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    final local = date.toLocal();

    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${two(local.day)}/'
        '${two(local.month)}/'
        '${local.year} '
        '${two(local.hour)}:'
        '${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sync'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMetadata,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            child: Icon(
                              _isAdmin
                                  ? Icons.admin_panel_settings
                                  : Icons.visibility,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isAdmin
                                      ? 'Admin Sync'
                                      : 'Viewer Sync',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isAdmin
                                      ? 'Upload the latest local data to Google Drive.'
                                      : 'Fetch the latest Admin data from Google Drive.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        leading: const Icon(
                          Icons.account_circle_outlined,
                        ),
                        title: const Text(
                          'Google Account',
                        ),
                        subtitle: Text(
                          _googleEmail ??
                              'Not connected',
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding:
                            EdgeInsets.zero,
                        leading: Icon(
                          _googleEmail == null
                              ? Icons.cloud_off
                              : Icons.cloud_done,
                        ),
                        title: const Text(
                          'Drive connection',
                        ),
                        subtitle: Text(
                          _googleEmail == null
                              ? 'Not connected'
                              : 'Connected',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isAdmin)
                _buildAdminSection()
              else
                _buildViewerSection(),
              const SizedBox(height: 16),
              _buildHistoryCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminSection() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Google Drive',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect your Google account before uploading data.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : _connectGoogleDrive,
                  icon: const Icon(
                    Icons.login,
                  ),
                  label: const Text(
                    'Connect Google Drive',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : _updateOnGoogleDrive,
                  icon: const Icon(
                    Icons.cloud_upload,
                  ),
                  label: const Text(
                    'Update on Google Drive',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Share with Viewer',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter a group member\'s Gmail address. '
                  'They will receive read-only access to the '
                  'Durgasevak Drive folder.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller:
                      _viewerEmailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  enabled: !_busy,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Viewer Gmail address',
                    hintText:
                        'member@gmail.com',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      _busy
                          ? null
                          : _shareFolder,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                  ),
                  label: const Text(
                    'Give Viewer Access',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Text(
              'Latest Data',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'The Viewer account can only read and fetch '
              'the Admin backup. It cannot upload or modify '
              'the Google Drive backup.',
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed:
                  _busy
                      ? null
                      : _connectGoogleDrive,
              icon: const Icon(
                Icons.login,
              ),
              label: const Text(
                'Connect Google Drive',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  _busy
                      ? null
                      : _fetchLatestData,
              icon: const Icon(
                Icons.cloud_download,
              ),
              label: const Text(
                'Fetch Latest Data',
              ),
            ),
            if (_driveModifiedTime != null) ...[
              const SizedBox(height: 16),
              ListTile(
                contentPadding:
                    EdgeInsets.zero,
                leading: const Icon(
                  Icons.cloud_outlined,
                ),
                title: const Text(
                  'Latest data on Google Drive',
                ),
                subtitle: Text(
                  _formatDate(
                    _driveModifiedTime,
                  ),
                ),
              ),
            ],
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
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Sync History',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding:
                  EdgeInsets.zero,
              leading: const Icon(
                Icons.upload_outlined,
              ),
              title: const Text(
                'Last uploaded',
              ),
              subtitle: Text(
                _formatDate(
                  _lastUploaded,
                ),
              ),
            ),
            ListTile(
              contentPadding:
                  EdgeInsets.zero,
              leading: const Icon(
                Icons.download_outlined,
              ),
              title: const Text(
                'Last downloaded',
              ),
              subtitle: Text(
                _formatDate(
                  _lastDownloaded,
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
