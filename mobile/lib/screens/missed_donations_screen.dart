import 'package:flutter/material.dart';

import '../database/database_service.dart';
import '../models/member.dart';
import '../services/auth_service.dart';
import '../utils/marathi_constants.dart';
import '../widgets/app_background.dart';
import '../widgets/whatsapp_icon.dart';
import 'member_missed_donations_screen.dart';

class MissedDonationsScreen extends StatefulWidget {
  final AuthUser? user;

  const MissedDonationsScreen({super.key, this.user});

  @override
  State<MissedDonationsScreen> createState() => _MissedDonationsScreenState();
}

class _MissedDonationsScreenState extends State<MissedDonationsScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  List<_MonthlyDonorStatus> _members = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final db = await _databaseService.database;

      final monthKey =
          '${_selectedMonth.year.toString().padLeft(4, '0')}-'
          '${_selectedMonth.month.toString().padLeft(2, '0')}';

      final rows = await db.rawQuery(
        '''
        SELECT
          m.id,
          m.name,
          m.mobile,
          m.address,
          CASE
            WHEN EXISTS (
              SELECT 1
              FROM donations d
              WHERE d.member_id = m.id
                AND d.monthly_donation = 1
                AND d.active = 1
                AND substr(d.date, 1, 7) = ?
            )
            THEN 1
            ELSE 0
          END AS paid
        FROM members m
        WHERE m.active = 1
        ORDER BY m.name COLLATE NOCASE ASC
        ''',
        [monthKey],
      );

      final members = rows.map((row) {
        return _MonthlyDonorStatus(
          memberId: row['id'] as int,
          memberName: row['name'] as String,
          mobile: row['mobile'] as String?,
          address: row['address'] as String?,
          paid: (row['paid'] as int? ?? 0) == 1,
        );
      }).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('प्रलंबित देणग्या लोड करण्यात अडचण आली: $e')),
      );
    }
  }

  Future<void> _selectMonth() async {
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return _MonthYearPickerDialog(initialMonth: _selectedMonth);
      },
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _selectedMonth = DateTime(selected.year, selected.month, 1);
    });

    await _loadData();
  }

  String get _selectedMonthLabel {
    return MarathiConstants.formatMonthYear(
      _selectedMonth.month,
      _selectedMonth.year,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paidCount = _members.where((member) => member.paid).length;

    final missedCount = _members.where((member) => !member.paid).length;

    return Scaffold(
      appBar: AppBar(title: const Text('प्रलंबित मासिक देणग्या')),
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _isLoading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 220),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: InkWell(
                        onTap: _selectMonth,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'निवडलेला महिना',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _selectedMonthLabel,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _SummaryBox(
                            title: 'एकूण सदस्य',
                            value: '${_members.length}',
                            icon: Icons.people,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryBox(
                            title: 'जमा',
                            value: '$paidCount',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryBox(
                            title: 'बाकी',
                            value: '$missedCount',
                            icon: Icons.warning_amber,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'सर्व सदस्य',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (_members.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: const [
                              Icon(
                                Icons.people_outline,
                                size: 56,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'कोणतेही सक्रिय सदस्य आढळले नाहीत',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < _members.length;
                              index++
                            ) ...[
                              _DonorStatusTile(
                                member: _members[index],
                                user:
                                    widget.user ??
                                    const AuthUser(
                                      id: 1,
                                      username: 'Admin',
                                      role: 'editor',
                                    ),
                                onRefresh: _loadData,
                              ),
                              if (index < _members.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MonthlyDonorStatus {
  final int memberId;
  final String memberName;
  final String? mobile;
  final String? address;
  final bool paid;

  const _MonthlyDonorStatus({
    required this.memberId,
    required this.memberName,
    this.mobile,
    this.address,
    required this.paid,
  });
}

class _SummaryBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Icon(icon, size: 23, color: Colors.deepOrange),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonorStatusTile extends StatelessWidget {
  final _MonthlyDonorStatus member;
  final AuthUser user;
  final VoidCallback onRefresh;

  const _DonorStatusTile({
    required this.member,
    required this.user,
    required this.onRefresh,
  });

  void _openDetails(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemberMissedDonationsScreen(
          member: Member(
            id: member.memberId,
            name: member.memberName,
            mobile: member.mobile,
            address: member.address,
          ),
          user: user,
        ),
      ),
    );
    onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _openDetails(context),
      leading: CircleAvatar(
        child: Text(
          member.memberName.isEmpty ? '?' : member.memberName[0].toUpperCase(),
        ),
      ),
      title: Text(
        member.memberName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: member.mobile != null
          ? Text(
              '+91 ${member.mobile!}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!member.paid && user.isAdmin)
            IconButton(
              icon: const WhatsAppIcon(size: 20),
              tooltip: 'व्हॉट्सॲप स्मरणपत्र पाठवा',
              onPressed: () => _openDetails(context),
            ),
          const SizedBox(width: 4),
          Icon(
            member.paid ? Icons.check_circle : Icons.cancel,
            color: member.paid ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            member.paid ? 'जमा' : 'बाकी',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: member.paid ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime initialMonth;

  const _MonthYearPickerDialog({required this.initialMonth});

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();

    _year = widget.initialMonth.year;
    _month = widget.initialMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('महिना निवडा'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _year--;
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_year',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _year++;
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),

          const SizedBox(height: 8),

          DropdownButtonFormField<int>(
            initialValue: _month,
            decoration: const InputDecoration(
              labelText: 'महिना',
              border: OutlineInputBorder(),
            ),
            items: List.generate(12, (index) {
              final month = index + 1;

              return DropdownMenuItem<int>(
                value: month,
                child: Text(MarathiConstants.getMonthName(month)),
              );
            }),
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _month = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('रद्द करा'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(DateTime(_year, _month, 1));
          },
          child: const Text('निवडा'),
        ),
      ],
    );
  }
}
