import 'package:flutter/material.dart';

import '../database/database_service.dart';
import '../widgets/app_background.dart';

class MissedDonationsScreen extends StatefulWidget {
  const MissedDonationsScreen({super.key});

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
        SnackBar(content: Text('Unable to load missed donations: $e')),
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

  String _monthName(int month) {
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

    return months[month - 1];
  }

  String get _selectedMonthLabel {
    return '${_monthName(_selectedMonth.month)} '
        '${_selectedMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    final paidCount = _members.where((member) => member.paid).length;

    final missedCount = _members.where((member) => !member.paid).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Missed Monthly Donations')),
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
                                      'Selected Month',
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
                            title: 'Members',
                            value: '${_members.length}',
                            icon: Icons.people,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryBox(
                            title: 'Paid',
                            value: '$paidCount',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SummaryBox(
                            title: 'Missed',
                            value: '$missedCount',
                            icon: Icons.warning_amber,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'All Members',
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
                                'No active members found',
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
                              _DonorStatusTile(member: _members[index]),
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
  final bool paid;

  const _MonthlyDonorStatus({
    required this.memberId,
    required this.memberName,
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

  const _DonorStatusTile({required this.member});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(
          member.memberName.isEmpty ? '?' : member.memberName[0].toUpperCase(),
        ),
      ),
      title: Text(
        member.memberName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            member.paid ? Icons.check_circle : Icons.cancel,
            color: member.paid ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            member.paid ? 'Paid' : 'Missed',
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

  String _monthName(int month) {
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

    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Month'),
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
              labelText: 'Month',
              border: OutlineInputBorder(),
            ),
            items: List.generate(12, (index) {
              final month = index + 1;

              return DropdownMenuItem<int>(
                value: month,
                child: Text(_monthName(month)),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(DateTime(_year, _month, 1));
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
