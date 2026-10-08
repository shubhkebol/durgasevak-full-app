import 'dart:io';

import 'package:flutter/material.dart';

import 'package:path/path.dart' as path;

import '../repositories/dashboard_repository.dart';
import '../services/auth_service.dart';
import '../services/database_backup_service.dart';
import '../services/file_intent_service.dart';
import '../services/google_drive_service.dart';
import '../services/sync_metadata_service.dart';
import '../widgets/app_background.dart';
import 'committee_screen.dart';
import 'data_sync_screen.dart';
import 'donation_payment_details_screen.dart';
import 'donations_screen.dart';
import 'expenses_screen.dart';
import 'login_screen.dart';
import 'members_screen.dart';
import 'missed_donations_screen.dart';
import 'mohim_screen.dart';
import 'reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  final AuthUser user;

  /// Backup file received through Android file sharing.
  ///
  /// This is normally populated when the app is opened by tapping a
  /// .durgasevak backup file while the user is not already logged in.
  final String? initialBackupPath;

  const DashboardScreen({
    super.key,
    required this.user,
    this.initialBackupPath,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardRepository _repository = DashboardRepository.instance;

  DashboardSummary? _summary;
  List<Map<String, dynamic>> _recentDonations = [];
  List<Map<String, dynamic>> _recentExpenses = [];

  bool _isLoading = true;
  bool _incomingFileHandled = false;

  @override
  void initState() {
    super.initState();

    FileIntentService.incomingFile.addListener(_handleIncomingFile);

    _loadDashboard();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialBackup();
      _handleIncomingFile();
    });
  }

  @override
  void dispose() {
    FileIntentService.incomingFile.removeListener(_handleIncomingFile);

    super.dispose();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final summary = await _repository.getSummary();
      final donations = await _repository.getRecentDonations();
      final expenses = await _repository.getRecentExpenses();

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _recentDonations = donations;
        _recentExpenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load dashboard: $e')));
    }
  }

  String _cleanError(Object error) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }

  Future<void> _quickFetchFromDrive() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'गुगल ड्राइव्हवरून डेटा आणत आहे...\n(Fetching data from Google Drive...)',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 25),
      ),
    );

    try {
      final driveService = GoogleDriveService.instance;
      await driveService.connect(isAdmin: widget.user.isAdmin);

      final fileId = await driveService.findBackupFile();
      if (fileId == null) {
        throw Exception(
          widget.user.isAdmin
              ? 'गुगल ड्राइव्हवर दुर्गसेवक बॅकअप सापडला नाही. कृपया डेटा सिंक स्क्रीनवरून प्रथम बॅकअप अपलोड करा.'
              : 'गुगल ड्राइव्हवर दुर्गसेवक बॅकअप सापडला नाही. कृपया ॲडमिनकडे तुमच्या ईमेलसाठी परवानगी मागा.',
        );
      }

      final tempDirectory = Directory.systemTemp;
      final targetPath = path.join(
        tempDirectory.path,
        'durgasevak_gdrive_${DateTime.now().millisecondsSinceEpoch}.db',
      );

      final downloadedPath = await driveService.downloadBackup(
        fileId,
        targetPath,
      );

      final backupService = DatabaseBackupService.instance;
      await backupService.restoreBackup(downloadedPath);

      final tempFile = File(downloadedPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'गुगल ड्राइव्हवरून डेटा यशस्वीरीत्या अपडेट झाला!\n(Data fetched successfully from Google Drive!)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF1B5E20),
          duration: Duration(seconds: 4),
        ),
      );

      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'डेटा आणताना अडचण आली: ${_cleanError(e)}',
            style: const TextStyle(fontSize: 13),
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _quickUploadToDrive() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'गुगल ड्राइव्हवर डेटा सेव्ह करत आहे...\n(Uploading and updating data to server...)',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    String? backupPath;
    try {
      final driveService = GoogleDriveService.instance;
      final account = await driveService.connect(isAdmin: true);

      final backupService = DatabaseBackupService.instance;
      backupPath = await backupService.createBackup();

      final now = DateTime.now().toIso8601String();
      final metadataService = SyncMetadataService.instance;
      await metadataService.set('last_exported_at', now);
      await metadataService.set('official_admin_gmail', account.email);

      final version = await backupService.getBackupDataVersion(backupPath);
      if (version != null) {
        await metadataService.set('local_data_version', version);
      }

      final folderId = await driveService.getOrCreateFolder();
      await driveService.uploadBackup(backupPath, folderId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'गुगल ड्राइव्हवर डेटा यशस्वीरीत्या सेव्ह झाला!\n(Data successfully updated to server! - ${account.email})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1B5E20),
          duration: const Duration(seconds: 4),
        ),
      );

      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'डेटा सेव्ह करताना अडचण आली: ${_cleanError(e)}',
            style: const TextStyle(fontSize: 13),
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (backupPath != null) {
        final file = File(backupPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  void _handleInitialBackup() {
    if (_incomingFileHandled) return;

    final path = widget.initialBackupPath;

    if (path == null || path.trim().isEmpty) {
      return;
    }

    _incomingFileHandled = true;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DataSyncScreen(user: widget.user, incomingBackupPath: path),
      ),
    );
  }

  void _handleIncomingFile() {
    if (!mounted) return;
    if (_incomingFileHandled) return;

    final path = FileIntentService.incomingFile.value;

    if (path == null || path.trim().isEmpty) {
      return;
    }

    if (!widget.user.isViewer) {
      FileIntentService.clearIncomingFile();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup import is available only for Viewer accounts.'),
        ),
      );

      return;
    }

    _incomingFileHandled = true;

    FileIntentService.clearIncomingFile();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DataSyncScreen(user: widget.user, incomingBackupPath: path),
      ),
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    await _loadDashboard();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.deepOrange),
            SizedBox(width: 10),
            Text('लॉगआउट करा'),
          ],
        ),
        content: const Text(
          'तुम्हाला खात्री आहे की तुम्हाला खात्यातून बाहेर पडायचे (Logout करायचे) आहे?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('रद्द करा', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('लॉगआउट'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await AuthService().logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _money(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return value;
    }

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  String _donorName(Map<String, dynamic> row) {
    if (row['donor_type'] == 'other') {
      final name = row['donor_name'] as String?;

      if (name == null || name.trim().isEmpty) {
        return 'इतर देणगीदार';
      }

      return name;
    }

    final name = row['member_name'] as String?;

    if (name == null || name.trim().isEmpty) {
      return 'सदस्य';
    }

    return name;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('दुर्गसेवक'),
        actions: [
          if (widget.user.isAdmin)
            IconButton(
              tooltip: 'गुगल ड्राइव्हवर डेटा सेव्ह करा',
              onPressed: _isLoading ? null : _quickUploadToDrive,
              icon: const Icon(Icons.cloud_upload),
            )
          else if (widget.user.isViewer)
            IconButton(
              tooltip: 'गुगल ड्राइव्हवरून डेटा आणा',
              onPressed: _isLoading ? null : _quickFetchFromDrive,
              icon: const Icon(Icons.cloud_download),
            ),
          IconButton(
            tooltip: 'रिफ्रेश करा',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'लॉगआउट',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: widget.user.isAdmin
              ? _quickUploadToDrive
              : _quickFetchFromDrive,
          child: _isLoading && summary == null
              ? ListView(
                  children: [
                    SizedBox(height: 280),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : summary == null
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 120),
                    const Icon(Icons.error_outline, size: 64),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'डॅशबोर्ड लोड करण्यात अडचण आली',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadDashboard,
                      child: const Text('पुन्हा प्रयत्न करा'),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 18),
                    _buildBalanceCard(summary),
                    const SizedBox(height: 14),
                    _buildQuickStats(summary),
                    const SizedBox(height: 22),
                    _buildModules(),
                    const SizedBox(height: 22),
                    _buildRecentDonations(),
                    const SizedBox(height: 18),
                    _buildRecentExpenses(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            widget.user.isAdmin
                ? 'assets/images/Admin.jpeg'
                : 'assets/images/Durgasevak.jpeg',
            width: 58,
            height: 58,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'पुन्हा स्वागत आहे',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 3),
              Text(
                widget.user.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.user.isAdmin ? 'प्रशासक' : 'निरीक्षक',
                style: const TextStyle(
                  color: Colors.deepOrangeAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceCard(DashboardSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined),
                SizedBox(width: 8),
                Text(
                  'सध्याची शिल्लक',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _money(summary.balance),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'सक्रिय देणग्या उणे सक्रिय खर्च',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(DashboardSummary summary) {
    return Column(
      children: [
        _statTile(
          Icons.people_outline,
          'सक्रिय सदस्य',
          '${summary.activeMembers}',
        ),
        const SizedBox(height: 8),
        _statTile(
          Icons.volunteer_activism,
          'एकूण देणग्या',
          _money(summary.totalDonations),
        ),
        const SizedBox(height: 8),
        _statTile(
          Icons.receipt_long,
          'एकूण खर्च',
          _money(summary.totalExpenses),
        ),
        const SizedBox(height: 8),
        _statTile(
          Icons.calendar_month,
          'मासिक देणग्या',
          _money(summary.monthlyDonations),
        ),
        const SizedBox(height: 8),
        _statTile(
          Icons.person_outline,
          'इतर देणग्या',
          _money(summary.otherDonations),
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String title, String value) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildModules() {
    final modules = [
      _Module(
        'सदस्य',
        Icons.people_outline,
        () => _open(MembersScreen(user: widget.user)),
      ),
      _Module(
        'UPI व बँक तपशील',
        Icons.qr_code_2,
        () => _open(DonationPaymentDetailsScreen(user: widget.user)),
      ),
      _Module(
        'देणग्या',
        Icons.volunteer_activism,
        () => _open(DonationsScreen(user: widget.user)),
      ),
      _Module(
        'खर्च',
        Icons.receipt_long,
        () => _open(ExpensesScreen(user: widget.user)),
      ),
      _Module(
        'मोहीम',
        Icons.campaign,
        () => _open(MohimScreen(user: widget.user)),
      ),
      _Module(
        'समिती',
        Icons.groups,
        () => _open(CommitteeScreen(user: widget.user)),
      ),
      _Module(
        'अहवाल',
        Icons.assessment,
        () => _open(ReportsScreen(user: widget.user)),
      ),
      _Module(
        'प्रलंबित देणग्या',
        Icons.event_busy,
        () => _open(MissedDonationsScreen(user: widget.user)),
      ),
      _Module(
        'डेटा सिंक',
        Icons.sync,
        () => _open(DataSyncScreen(user: widget.user)),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'विभाग',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (_, index) {
            final module = modules[index];

            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: module.onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(module.icon, size: 34),
                    const SizedBox(height: 8),
                    Text(
                      module.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentDonations() {
    return _recentSection(
      title: 'अलीकडील देणग्या',
      onViewAll: () => _open(DonationsScreen(user: widget.user)),
      emptyText: 'एकही देणगी उपलब्ध नाही',
      children: _recentDonations.map((row) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;

        final monthly = (row['monthly_donation'] as int? ?? 0) == 1;

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.volunteer_activism)),
          title: Text(
            _donorName(row),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(_formatDate(row['date'] as String?)),
              if (monthly) ...[
                const SizedBox(width: 8),
                const Chip(
                  label: Text('मासिक'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          trailing: Text(
            _money(amount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentExpenses() {
    return _recentSection(
      title: 'अलीकडील खर्च',
      onViewAll: () => _open(ExpensesScreen(user: widget.user)),
      emptyText: 'एकही खर्च उपलब्ध नाही',
      children: _recentExpenses.map((row) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;

        final category = row['category'] as String?;

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
          title: Text(
            category == null || category.trim().isEmpty ? 'खर्च' : category,
          ),
          subtitle: Text(_formatDate(row['date'] as String?)),
          trailing: Text(
            _money(amount),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }

  Widget _recentSection({
    required String title,
    required VoidCallback onViewAll,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(onPressed: onViewAll, child: const Text('सर्व पहा')),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: children.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(child: Text(emptyText)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i < children.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Module {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _Module(this.title, this.icon, this.onTap);
}
