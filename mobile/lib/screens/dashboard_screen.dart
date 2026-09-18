import 'dart:io';

import 'package:flutter/material.dart';

import '../repositories/dashboard_repository.dart';
import '../services/auth_service.dart';
import '../services/backend_sync_service.dart';
import '../services/database_backup_service.dart';
import '../services/file_intent_service.dart';
import '../widgets/app_background.dart';
import 'committee_screen.dart';
import 'data_sync_screen.dart';
import 'donations_screen.dart';
import 'expenses_screen.dart';
import 'members_screen.dart';
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

  Future<void> _quickFetchFromCloud() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fetching latest data from cloud...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final syncService = BackendSyncService.instance;
      // Viewers can use the default viewer account
      final token = await syncService.login('Durgasevak', 'Durgasevak');
      
      final tempDirectory = Directory.systemTemp;
      final downloadedPath = await syncService.downloadLatestBackup(tempDirectory.path, token);

      if (!mounted) return;

      final backupService = DatabaseBackupService.instance;
      await backupService.restoreBackup(downloadedPath);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dashboard successfully updated from cloud!')),
      );

      await _loadDashboard();
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch from cloud: $e')),
      );
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

  void _logout() {
    Navigator.of(context).pop();
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
        return 'Other Donor';
      }

      return name;
    }

    final name = row['member_name'] as String?;

    if (name == null || name.trim().isEmpty) {
      return 'Member';
    }

    return name;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Durgasevak'),
        actions: [
          if (widget.user.isViewer)
            IconButton(
              tooltip: 'Fetch from Cloud',
              onPressed: _isLoading ? null : _quickFetchFromCloud,
              icon: const Icon(Icons.cloud_download),
            ),
          IconButton(
            tooltip: 'Refresh Local',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: widget.user.isViewer ? _quickFetchFromCloud : _loadDashboard,
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
                        'Unable to load dashboard',
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
                      child: const Text('Retry'),
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
                'Welcome back',
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
                widget.user.isAdmin ? 'Administrator' : 'Viewer',
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
                  'Current Balance',
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
              'Active donations minus active expenses',
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
          'Active Members',
          '${summary.activeMembers}',
        ),
        const SizedBox(height: 8),
        _statTile(
          Icons.volunteer_activism,
          'Total Donations',
          _money(summary.totalDonations),
        ),
        const SizedBox(height: 8),
        _statTile(
          Icons.receipt_long,
          'Total Expenses',
          _money(summary.totalExpenses),
        ),
        const SizedBox(height: 8),
        _statTile(
          Icons.calendar_month,
          'Monthly Donations',
          _money(summary.monthlyDonations),
        ),
        const SizedBox(height: 8),
        _statTile(
          Icons.person_outline,
          'Other Donations',
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
        'Members',
        Icons.people_outline,
        () => _open(MembersScreen(user: widget.user)),
      ),
      _Module(
        'Donations',
        Icons.volunteer_activism,
        () => _open(DonationsScreen(user: widget.user)),
      ),
      _Module(
        'Expenses',
        Icons.receipt_long,
        () => _open(ExpensesScreen(user: widget.user)),
      ),
      _Module(
        'Mohim',
        Icons.campaign,
        () => _open(MohimScreen(user: widget.user)),
      ),
      _Module(
        'Committee',
        Icons.groups,
        () => _open(CommitteeScreen(user: widget.user)),
      ),
      _Module(
        'Reports',
        Icons.assessment,
        () => _open(ReportsScreen(user: widget.user)),
      ),
      _Module(
        'Data Sync',
        Icons.sync,
        () => _open(DataSyncScreen(user: widget.user)),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modules',
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
      title: 'Recent Donations',
      onViewAll: () => _open(DonationsScreen(user: widget.user)),
      emptyText: 'No recent donations',
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
                  label: Text('Monthly'),
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
      title: 'Recent Expenses',
      onViewAll: () => _open(ExpensesScreen(user: widget.user)),
      emptyText: 'No recent expenses',
      children: _recentExpenses.map((row) {
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;

        final category = row['category'] as String?;

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
          title: Text(
            category == null || category.trim().isEmpty ? 'Expense' : category,
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
            TextButton(onPressed: onViewAll, child: const Text('View All')),
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
