import 'package:flutter/material.dart';

import '../models/member.dart';
import '../repositories/member_repository.dart';
import '../services/auth_service.dart';
import '../widgets/app_background.dart';
import '../widgets/whatsapp_icon.dart';
import 'member_missed_donations_screen.dart';
import 'missed_donations_screen.dart';

class MembersScreen extends StatefulWidget {
  final AuthUser user;

  const MembersScreen({super.key, required this.user});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final MemberRepository _repository = MemberRepository.instance;

  List<Member> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final members = await _repository.getActiveMembers();

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('सदस्य लोड करण्यात अडचण आली: $e')));
    }
  }

  Future<void> _showMemberForm({Member? member}) async {
    if (!widget.user.isAdmin) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) {
        return MemberFormDialog(member: member, repository: _repository);
      },
    );

    if (saved == true && mounted) {
      await _loadMembers();
    }
  }

  Future<void> _deactivateMember(Member member) async {
    if (!widget.user.isAdmin || member.id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('सदस्य निष्क्रिय करा'),
          content: Text(
            'तुम्हाला नक्की ${member.name} यांना निष्क्रिय करायचे आहे का?',
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
              child: const Text('निष्क्रिय करा'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deactivateMember(member.id!);

      if (!mounted) {
        return;
      }

      await _loadMembers();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} यांना निष्क्रिय केले')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('सदस्य निष्क्रिय करण्यात अडचण आली: $e')),
      );
    }
  }

  Future<void> _openMemberMissedDonations(Member member) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MemberMissedDonationsScreen(member: member, user: widget.user),
      ),
    );

    if (mounted) {
      await _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('सदस्य'),
        actions: [
          IconButton(
            tooltip: 'प्रलंबित मासिक देणग्या',
            icon: const Icon(Icons.event_busy),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MissedDonationsScreen(user: widget.user),
                ),
              );
            },
          ),
        ],
      ),
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _members.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
                onRefresh: _loadMembers,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];

                    return Card(
                      child: ListTile(
                        onTap: () => _openMemberMissedDonations(member),
                        leading: CircleAvatar(
                          child: Text(
                            member.name.isEmpty
                                ? '?'
                                : member.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(member.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (member.mobile != null)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 13,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+91 ${member.mobile!}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            if (member.address != null) Text(member.address!),
                          ],
                        ),
                        isThreeLine:
                            member.mobile != null && member.address != null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.user.isAdmin)
                              IconButton(
                                icon: const WhatsAppIcon(size: 22),
                                tooltip:
                                    'प्रलंबित देणग्या व व्हॉट्सॲप स्मरणपत्र',
                                onPressed: () =>
                                    _openMemberMissedDonations(member),
                              ),
                            if (widget.user.isAdmin)
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'donations') {
                                    _openMemberMissedDonations(member);
                                  } else if (value == 'edit') {
                                    _showMemberForm(member: member);
                                  } else if (value == 'deactivate') {
                                    _deactivateMember(member);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'donations',
                                    child: Row(
                                      children: [
                                        WhatsAppIcon(size: 18),
                                        SizedBox(width: 8),
                                        Text('प्रलंबित देणग्या व व्हॉट्सॲप'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('संपादित करा'),
                                  ),
                                  PopupMenuItem(
                                    value: 'deactivate',
                                    child: Text('निष्क्रिय करा'),
                                  ),
                                ],
                              )
                            else
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: widget.user.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showMemberForm(),
              icon: const Icon(Icons.person_add),
              label: const Text('सदस्य जोडा'),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView(
        children: const [
          SizedBox(height: 180),
          Icon(Icons.people_outline, size: 72, color: Colors.grey),
          SizedBox(height: 16),
          Center(
            child: Text(
              'एकही सदस्य आढळला नाही',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'नवीन सदस्य जोडण्यासाठी "सदस्य जोडा" वर टॅप करा.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class MemberFormDialog extends StatefulWidget {
  final Member? member;
  final MemberRepository repository;

  const MemberFormDialog({super.key, this.member, required this.repository});

  @override
  State<MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<MemberFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _addressController;

  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.member?.name ?? '');

    _mobileController = TextEditingController(
      text: widget.member?.mobile ?? '',
    );

    _addressController = TextEditingController(
      text: widget.member?.address ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final member = Member(
      id: widget.member?.id,
      name: _nameController.text.trim(),
      mobile: _mobileController.text.trim().isEmpty
          ? null
          : _mobileController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      active: true,
    );

    try {
      if (widget.member == null) {
        await widget.repository.addMember(member);
      } else {
        await widget.repository.updateMember(member);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('सदस्य जतन करण्यात अडचण आली: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.member != null;

    return AlertDialog(
      title: Text(isEditing ? 'सदस्य माहिती संपादित करा' : 'नवीन सदस्य जोडा'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'नाव',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'नाव आवश्यक आहे';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobileController,
                enabled: !_isSaving,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'मोबाईल नंबर',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'पत्ता',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('रद्द करा'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'अपडेट करा' : 'जतन करा'),
        ),
      ],
    );
  }
}
