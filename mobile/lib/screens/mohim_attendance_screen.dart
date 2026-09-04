import 'package:flutter/material.dart';

import '../models/member.dart';
import '../repositories/mohim_attendance_repository.dart';
import '../services/auth_service.dart';
import '../widgets/app_background.dart';

class MohimAttendanceScreen extends StatefulWidget {
  final int mohimId;
  final String mohimName;
  final String? startDate;
  final String? endDate;
  final String? description;
  final AuthUser user;

  const MohimAttendanceScreen({
    super.key,
    required this.mohimId,
    required this.mohimName,
    this.startDate,
    this.endDate,
    this.description,
    required this.user,
  });

  @override
  State<MohimAttendanceScreen> createState() => _MohimAttendanceScreenState();
}

class _MohimAttendanceScreenState extends State<MohimAttendanceScreen> {
  final MohimAttendanceRepository _repository =
      MohimAttendanceRepository.instance;

  final TextEditingController _visitorController = TextEditingController();

  List<Member> _members = [];
  Set<int> _presentMemberIds = {};
  List<String> _otherVisitors = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void dispose() {
    _visitorController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final members = await _repository.getActiveMembers();

      final presentMemberIds = await _repository.getPresentMemberIds(
        widget.mohimId,
      );

      final otherVisitors = await _repository.getOtherVisitors(widget.mohimId);

      if (!mounted) {
        return;
      }

      setState(() {
        _members = members;
        _presentMemberIds = presentMemberIds;
        _otherVisitors = otherVisitors;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to load attendance: $e')));
    }
  }

  Future<void> _toggleMember(Member member, bool present) async {
    if (!widget.user.isAdmin || member.id == null || _isSaving) {
      return;
    }

    final memberId = member.id!;

    setState(() {
      _isSaving = true;

      if (present) {
        _presentMemberIds = {..._presentMemberIds, memberId};
      } else {
        _presentMemberIds = Set<int>.from(_presentMemberIds)..remove(memberId);
      }
    });

    try {
      if (present) {
        await _repository.markMemberPresent(
          mohimId: widget.mohimId,
          memberId: memberId,
        );
      } else {
        await _repository.markMemberAbsent(
          mohimId: widget.mohimId,
          memberId: memberId,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (present) {
          _presentMemberIds = Set<int>.from(_presentMemberIds)
            ..remove(memberId);
        } else {
          _presentMemberIds = {..._presentMemberIds, memberId};
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update attendance: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _addVisitor() async {
    if (!widget.user.isAdmin || _isSaving) {
      return;
    }

    final name = _visitorController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter visitor name')),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.addOtherVisitor(
        mohimId: widget.mohimId,
        visitorName: name,
      );

      _visitorController.clear();

      final visitors = await _repository.getOtherVisitors(widget.mohimId);

      if (!mounted) {
        return;
      }

      setState(() {
        _otherVisitors = visitors;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to add visitor: $e')));
    }
  }

  Future<void> _removeVisitor(String name) async {
    if (!widget.user.isAdmin || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.removeOtherVisitor(
        mohimId: widget.mohimId,
        visitorName: name,
      );

      final visitors = await _repository.getOtherVisitors(widget.mohimId);

      if (!mounted) {
        return;
      }

      setState(() {
        _otherVisitors = visitors;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to remove visitor: $e')));
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.trim().isEmpty) {
      return '';
    }

    final parsed = DateTime.tryParse(date);

    if (parsed == null) {
      return date;
    }

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  String _dateRange() {
    final start = _formatDate(widget.startDate);
    final end = _formatDate(widget.endDate);

    if (start.isEmpty && end.isEmpty) {
      return '';
    }

    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }

    if (start.isNotEmpty) {
      return 'Started: $start';
    }

    return 'Ends: $end';
  }

  @override
  Widget build(BuildContext context) {
    final presentMemberCount = _presentMemberIds.length;

    final totalMemberCount = _members.length;

    final otherVisitorCount = _otherVisitors.length;

    final totalPresent = presentMemberCount + otherVisitorCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAttendance,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildMohimHeader(),
                    const SizedBox(height: 16),
                    _buildSummary(
                      presentMemberCount,
                      totalMemberCount,
                      otherVisitorCount,
                      totalPresent,
                    ),
                    const SizedBox(height: 20),
                    _buildMembersSection(),
                    const SizedBox(height: 20),
                    _buildVisitorsSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMohimHeader() {
    final range = _dateRange();

    final hasDescription =
        widget.description != null && widget.description!.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.campaign, size: 25),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.mohimName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (range.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.calendar_today, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      range,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (hasDescription) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                widget.description!.trim(),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(
    int presentMemberCount,
    int totalMemberCount,
    int otherVisitorCount,
    int totalPresent,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$presentMemberCount / '
                    '$totalMemberCount Members Present',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_add_alt_1, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('$otherVisitorCount Other Visitors')),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                const Icon(Icons.groups, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Total Present: $totalPresent',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(4),
              child: Row(
                children: [
                  Icon(Icons.people_outline),
                  SizedBox(width: 8),
                  Text(
                    'Registered Members',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                widget.user.isAdmin
                    ? 'Check members who are Present.'
                    : 'Attendance is read-only.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            if (_members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No active members found.')),
              )
            else
              Container(
                height: 360,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _members.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return _buildMemberTile(_members[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Member member) {
    final memberId = member.id;

    final isPresent = memberId != null && _presentMemberIds.contains(memberId);

    final mobile = member.mobile?.trim() ?? '';

    return CheckboxListTile(
      value: isPresent,
      onChanged: widget.user.isAdmin && memberId != null && !_isSaving
          ? (value) {
              _toggleMember(member, value ?? false);
            }
          : null,
      title: Text(
        member.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: mobile.isEmpty
          ? Text(
              isPresent ? 'Present' : 'Absent',
              style: TextStyle(
                color: isPresent ? Colors.greenAccent : Colors.white54,
              ),
            )
          : Text(mobile, style: const TextStyle(color: Colors.white70)),
      secondary: Icon(
        isPresent ? Icons.check_circle : Icons.person_outline,
        color: isPresent ? Colors.greenAccent : Colors.white54,
      ),
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  Widget _buildVisitorsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_add_alt_1),
                SizedBox(width: 8),
                Text(
                  'Other Visitors',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.user.isAdmin)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _visitorController,
                      enabled: !_isSaving,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Visitor Name',
                        hintText: 'Enter other person name',
                        prefixIcon: Icon(Icons.person_add),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        _addVisitor();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSaving ? null : _addVisitor,
                    icon: const Icon(Icons.add),
                    tooltip: 'Add Visitor',
                  ),
                ],
              ),
            if (widget.user.isAdmin) const SizedBox(height: 12),
            if (_otherVisitors.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No other visitors added.'),
              )
            else
              ..._otherVisitors.map(
                (name) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(name),
                  subtitle: const Text(
                    'Present',
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                  trailing: widget.user.isAdmin
                      ? IconButton(
                          onPressed: _isSaving
                              ? null
                              : () {
                                  _removeVisitor(name);
                                },
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove Visitor',
                        )
                      : const Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
