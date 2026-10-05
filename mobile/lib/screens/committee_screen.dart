import 'package:flutter/material.dart';

import '../models/committee.dart';
import '../models/member.dart';
import '../repositories/committee_repository.dart';
import '../repositories/member_repository.dart';
import '../services/auth_service.dart';
import '../widgets/app_background.dart';

class CommitteeScreen extends StatefulWidget {
  final AuthUser user;

  const CommitteeScreen({super.key, required this.user});

  @override
  State<CommitteeScreen> createState() => _CommitteeScreenState();
}

class _CommitteeScreenState extends State<CommitteeScreen> {
  final CommitteeRepository _repository = CommitteeRepository.instance;
  final MemberRepository _memberRepository = MemberRepository.instance;

  List<Committee> _committee = [];
  bool _isLoading = true;

  bool get _isAdmin => widget.user.isAdmin;

  @override
  void initState() {
    super.initState();
    _loadCommittee();
  }

  Future<void> _loadCommittee() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final committee = await _repository.getAll();

      if (!mounted) return;

      setState(() {
        _committee = committee;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('समिती माहिती लोड करण्यात अडचण आली: $e', isError: true);
    }
  }

  Future<void> _addCommitteeMember() async {
    await _showCommitteeDialog();
  }

  Future<void> _editCommitteeMember(Committee committee) async {
    await _showCommitteeDialog(committee: committee);
  }

  Future<void> _showCommitteeDialog({Committee? committee}) async {
    final members = await _memberRepository.getActiveMembers();

    if (!mounted) return;

    Member? selectedMember;

    if (committee != null) {
      for (final member in members) {
        if (member.id == committee.memberId) {
          selectedMember = member;
          break;
        }
      }
    }

    final result = await showDialog<_CommitteeDialogResult>(
      context: context,
      builder: (dialogContext) {
        return _CommitteeDialog(
          members: members,
          initialMember: selectedMember,
          initialPosition: committee?.position ?? '',
          isEditing: committee != null,
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      if (committee == null) {
        await _repository.add(
          position: result.position,
          memberId: result.member.id!,
        );
      } else {
        await _repository.update(
          id: committee.id!,
          position: result.position,
          memberId: result.member.id!,
        );
      }

      await _loadCommittee();

      if (!mounted) return;

      _showMessage(
        committee == null ? 'समिती सदस्य जोडला.' : 'समिती सदस्य अपडेट केला.',
      );
    } catch (e) {
      if (!mounted) return;

      String message = e.toString();

      if (message.startsWith('DatabaseException')) {
        message = 'हे पद किंवा सदस्य समितीमध्ये आधीच नियुक्त आहे.';
      }

      _showMessage(message, isError: true);
    }
  }

  Future<void> _deleteCommitteeMember(Committee committee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('समिती सदस्य काढा'),
          content: Text(
            '${committee.memberName} यांना '
            '${committee.position} या पदावरून काढायचे आहे का?',
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
              child: const Text('काढा'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.delete(committee.id!);

      await _loadCommittee();

      if (!mounted) return;

      _showMessage('समिती सदस्य काढला.');
    } catch (e) {
      if (!mounted) return;

      _showMessage('समिती सदस्य काढण्यात अडचण आली: $e', isError: true);
    }
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
      appBar: AppBar(
        title: const Text('समिती'),
        actions: [
          IconButton(
            tooltip: 'रिफ्रेश करा',
            onPressed: _isLoading ? null : _loadCommittee,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadCommittee,
                  child: _committee.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 120),
                            const Icon(
                              Icons.groups_outlined,
                              size: 70,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                'अद्याप कोणतेही समिती सदस्य जोडलेले नाहीत.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            if (_isAdmin) ...[
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _addCommitteeMember,
                                icon: const Icon(Icons.add),
                                label: const Text('समिती सदस्य जोडा'),
                              ),
                            ],
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 16),
                            ..._committee.map(_buildCommitteeCard),
                          ],
                        ),
                ),
        ),
      ),
      floatingActionButton: _isAdmin && _committee.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _addCommitteeMember,
              icon: const Icon(Icons.add),
              label: const Text('जोडा'),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.groups, size: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'समिती',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_committee.length} समिती सदस्य',
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

  Widget _buildCommitteeCard(Committee committee) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(
          committee.position,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            committee.memberName,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        trailing: _isAdmin
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editCommitteeMember(committee);
                  } else if (value == 'delete') {
                    _deleteCommitteeMember(committee);
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 10),
                          Text('संपादित करा'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 10),
                          Text('काढा'),
                        ],
                      ),
                    ),
                  ];
                },
              )
            : null,
      ),
    );
  }
}

class _CommitteeDialogResult {
  final String position;
  final Member member;

  const _CommitteeDialogResult({required this.position, required this.member});
}

class _CommitteeDialog extends StatefulWidget {
  final List<Member> members;
  final Member? initialMember;
  final String initialPosition;
  final bool isEditing;

  const _CommitteeDialog({
    required this.members,
    required this.initialMember,
    required this.initialPosition,
    required this.isEditing,
  });

  @override
  State<_CommitteeDialog> createState() => _CommitteeDialogState();
}

class _CommitteeDialogState extends State<_CommitteeDialog> {
  late final TextEditingController _positionController;

  Member? _selectedMember;
  String _search = '';

  @override
  void initState() {
    super.initState();

    _positionController = TextEditingController(text: widget.initialPosition);

    _selectedMember = widget.initialMember;
  }

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = widget.members.where((member) {
      final search = _search.trim().toLowerCase();

      if (search.isEmpty) {
        return true;
      }

      return member.name.toLowerCase().contains(search) ||
          (member.mobile ?? '').toLowerCase().contains(search);
    }).toList();

    return AlertDialog(
      title: Text(
        widget.isEditing ? 'समिती सदस्य संपादित करा' : 'समिती सदस्य जोडा',
      ),
      content: SizedBox(
        width: 500,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _positionController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'पद',
                hintText: 'उदा. अध्यक्ष, सचिव, खजिनदार',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'व्यक्ती निवडा',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                hintText: 'सदस्य शोधा',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _search = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredMembers.isEmpty
                  ? const Center(
                      child: Text('कोणतेही सक्रिय सदस्य आढळले नाहीत.'),
                    )
                  : ListView.builder(
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];

                        final selected = _selectedMember?.id == member.id;

                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            child: Text(
                              member.name.trim().isEmpty
                                  ? '?'
                                  : member.name
                                        .trim()
                                        .substring(0, 1)
                                        .toUpperCase(),
                            ),
                          ),
                          title: Text(member.name),
                          subtitle:
                              member.mobile == null ||
                                  member.mobile!.trim().isEmpty
                              ? null
                              : Text(member.mobile!),
                          trailing: selected
                              ? const Icon(Icons.check_circle)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedMember = member;
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('रद्द करा'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.isEditing ? 'अपडेट करा' : 'जतन करा'),
        ),
      ],
    );
  }

  void _save() {
    final position = _positionController.text.trim();

    if (position.isEmpty) {
      _showError('कृपया पद प्रविष्ट करा.');
      return;
    }

    if (_selectedMember == null) {
      _showError('कृपया सदस्यांमधून व्यक्ती निवडा.');
      return;
    }

    Navigator.of(
      context,
    ).pop(_CommitteeDialogResult(position: position, member: _selectedMember!));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
