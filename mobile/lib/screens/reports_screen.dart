import 'package:flutter/material.dart';

import '../repositories/report_repository.dart';
import '../services/auth_service.dart';
import '../widgets/app_background.dart';

class ReportsScreen extends StatefulWidget {
  final AuthUser user;

  const ReportsScreen({super.key, required this.user});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final ReportRepository _repository = ReportRepository.instance;

  DateTime? _startDate;
  DateTime? _endDate;

  bool _isLoading = true;

  Map<String, double> _financialSummary = {
    'donations': 0,
    'expenses': 0,
    'balance': 0,
  };

  List<Map<String, dynamic>> _donations = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _memberWise = [];
  List<Map<String, dynamic>> _monthly = [];
  List<Map<String, dynamic>> _otherDonors = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  String _databaseDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _displayDate(DateTime? date) {
    if (date == null) {
      return 'Not selected';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final start = _startDate == null ? null : _databaseDate(_startDate!);

      // End date is inclusive.
      // Repository receives the next day as the exclusive boundary.
      final endExclusive = _endDate == null
          ? null
          : _databaseDate(_endDate!.add(const Duration(days: 1)));

      final results = await Future.wait([
        _repository.getFinancialSummary(
          startDate: start,
          endDate: endExclusive,
        ),
        _repository.getDonationReport(startDate: start, endDate: endExclusive),
        _repository.getExpenseReport(startDate: start, endDate: endExclusive),
        _repository.getMemberWiseDonations(
          startDate: start,
          endDate: endExclusive,
        ),
        _repository.getMonthlyDonationSummary(
          startDate: start,
          endDate: endExclusive,
        ),
        _repository.getOtherDonorSummary(
          startDate: start,
          endDate: endExclusive,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _financialSummary = results[0] as Map<String, double>;

        _donations = results[1] as List<Map<String, dynamic>>;

        _expenses = results[2] as List<Map<String, dynamic>>;

        _memberWise = results[3] as List<Map<String, dynamic>>;

        _monthly = results[4] as List<Map<String, dynamic>>;

        _otherDonors = results[5] as List<Map<String, dynamic>>;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to load reports: $e')));
    }
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'SELECT START DATE',
    );

    if (selected == null || !mounted) {
      return;
    }

    if (_endDate != null && selected.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start date cannot be after end date')),
      );
      return;
    }

    setState(() {
      _startDate = selected;
    });

    await _loadReports();
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'SELECT END DATE',
    );

    if (selected == null || !mounted) {
      return;
    }

    if (_startDate != null && selected.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be before start date')),
      );
      return;
    }

    setState(() {
      _endDate = selected;
    });

    await _loadReports();
  }

  Future<void> _clearFilters() async {
    setState(() {
      _startDate = null;
      _endDate = null;
    });

    await _loadReports();
  }

  String _formatAmount(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    final date = DateTime.tryParse(value);

    if (date == null) {
      return value;
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _donorName(Map<String, dynamic> row) {
    if (row['donor_type'] == 'other') {
      final donorName = row['donor_name'] as String?;

      if (donorName != null && donorName.trim().isNotEmpty) {
        return donorName;
      }

      return 'Other Donor';
    }

    final memberName = row['member_name'] as String?;

    if (memberName != null && memberName.trim().isNotEmpty) {
      return memberName;
    }

    return 'Member';
  }

  String _formatMonth(String? value) {
    if (value == null || value.length != 7) {
      return value ?? '';
    }

    final parts = value.split('-');

    if (parts.length != 2) {
      return value;
    }

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final month = int.tryParse(parts[1]);

    if (month == null || month < 1 || month > 12) {
      return value;
    }

    return '${months[month - 1]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadReports,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildFilters(),
                    Expanded(child: _buildReportTabs()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final hasFilter = _startDate != null || _endDate != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _DateFilterButton(
                    label: 'Start Date',
                    value: _displayDate(_startDate),
                    icon: Icons.calendar_today,
                    onTap: _selectStartDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateFilterButton(
                    label: 'End Date',
                    value: _displayDate(_endDate),
                    icon: Icons.event,
                    onTap: _selectEndDate,
                  ),
                ),
              ],
            ),
            if (hasFilter) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Filters'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportTabs() {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(icon: Icon(Icons.account_balance), text: 'Financial'),
                Tab(icon: Icon(Icons.volunteer_activism), text: 'Donations'),
                Tab(icon: Icon(Icons.receipt_long), text: 'Expenses'),
                Tab(icon: Icon(Icons.people), text: 'Members'),
                Tab(icon: Icon(Icons.calendar_month), text: 'Monthly'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              children: [
                _buildFinancialReport(),
                _buildDonationReport(),
                _buildExpenseReport(),
                _buildMemberReport(),
                _buildMonthlyReport(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialReport() {
    final donations = _financialSummary['donations'] ?? 0;

    final expenses = _financialSummary['expenses'] ?? 0;

    final balance = _financialSummary['balance'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _ReportAmountCard(
          title: 'Total Donations',
          amount: donations,
          icon: Icons.volunteer_activism,
        ),
        _ReportAmountCard(
          title: 'Total Expenses',
          amount: expenses,
          icon: Icons.receipt_long,
        ),
        _ReportAmountCard(
          title: 'Balance',
          amount: balance,
          icon: Icons.account_balance_wallet,
        ),
        const SizedBox(height: 10),
        _ReportCountCard(
          title: 'Donation Transactions',
          count: _donations.length,
          icon: Icons.payments,
        ),
        _ReportCountCard(
          title: 'Expense Transactions',
          count: _expenses.length,
          icon: Icons.receipt,
        ),
        _ReportCountCard(
          title: 'Other Donor Records',
          count: _otherDonors.length,
          icon: Icons.person_outline,
        ),
      ],
    );
  }

  Widget _buildDonationReport() {
    if (_donations.isEmpty) {
      return _emptyReport('No donations found', Icons.volunteer_activism);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _donations.length,
      itemBuilder: (context, index) {
        final row = _donations[index];

        final amount = (row['amount'] as num).toDouble();

        final monthly = (row['monthly_donation'] as int? ?? 0) == 1;

        final note = row['note'] as String?;

        return _ReportTransactionCard(
          icon: Icons.volunteer_activism,
          title: _donorName(row),
          amount: _formatAmount(amount),
          date: _formatDate(row['date'] as String?),
          badge: monthly ? 'Monthly Donation' : null,
          note: note,
        );
      },
    );
  }

  Widget _buildExpenseReport() {
    if (_expenses.isEmpty) {
      return _emptyReport('No expenses found', Icons.receipt_long);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final row = _expenses[index];

        final amount = (row['amount'] as num).toDouble();

        final category = row['category'] as String?;

        final note = row['note'] as String?;

        return _ReportTransactionCard(
          icon: Icons.receipt_long,
          title: category != null && category.trim().isNotEmpty
              ? category
              : 'Expense',
          amount: _formatAmount(amount),
          date: _formatDate(row['date'] as String?),
          note: note,
        );
      },
    );
  }

  Widget _buildMemberReport() {
    if (_memberWise.isEmpty) {
      return _emptyReport('No member donations found', Icons.people);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _memberWise.length,
      itemBuilder: (context, index) {
        final row = _memberWise[index];

        final amount = (row['total_amount'] as num).toDouble();

        final count = (row['donation_count'] as num).toInt();

        final memberName = row['member_name'] as String? ?? 'Member';

        return Card(
          color: Colors.black.withValues(alpha: 0.84),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$count donation'
                        '${count == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatAmount(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthlyReport() {
    if (_monthly.isEmpty && _otherDonors.isEmpty) {
      return _emptyReport('No monthly data found', Icons.calendar_month);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_monthly.isNotEmpty) ...[
          const _SectionTitle(
            icon: Icons.calendar_month,
            title: 'Monthly Donations',
          ),
          const SizedBox(height: 8),
          ..._monthly.map((row) {
            final amount = (row['total_amount'] as num).toDouble();

            final count = (row['donation_count'] as num).toInt();

            return Card(
              color: Colors.black.withValues(alpha: 0.84),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  child: const Icon(Icons.calendar_month, color: Colors.white),
                ),
                title: Text(
                  _formatMonth(row['month'] as String?),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '$count donation'
                  '${count == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
                ),
                trailing: Text(
                  _formatAmount(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 8),
        const _SectionTitle(icon: Icons.person_outline, title: 'Other Donors'),
        const SizedBox(height: 8),
        if (_otherDonors.isEmpty)
          _simpleMessageCard('No other-donor donations found.')
        else
          ..._otherDonors.map((row) {
            final amount = (row['total_amount'] as num).toDouble();

            final count = (row['donation_count'] as num).toInt();

            return Card(
              color: Colors.black.withValues(alpha: 0.84),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  child: const Icon(Icons.person_outline, color: Colors.white),
                ),
                title: Text(
                  row['donor_name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '$count donation'
                  '${count == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
                ),
                trailing: Text(
                  _formatAmount(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _simpleMessageCard(String message) {
    return Card(
      color: Colors.black.withValues(alpha: 0.84),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          message,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
      ),
    );
  }

  Widget _emptyReport(String message, IconData icon) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 70),
        Center(
          child: CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            child: Icon(icon, size: 40, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Try changing the selected date range.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.60)),
          ),
        ),
      ],
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
        child: Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _ReportAmountCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;

  const _ReportAmountCard({
    required this.title,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: 0.84),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          '₹${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ReportCountCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _ReportCountCard({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withValues(alpha: 0.84),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ReportTransactionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String amount;
  final String date;
  final String? badge;
  final String? note;

  const _ReportTransactionCard({
    required this.icon,
    required this.title,
    required this.amount,
    required this.date,
    this.badge,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final hasNote = note != null && note!.trim().isNotEmpty;

    return Card(
      color: Colors.black.withValues(alpha: 0.84),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  if (hasNote) ...[
                    const SizedBox(height: 6),
                    Text(
                      note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
