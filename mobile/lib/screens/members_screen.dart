import 'package:flutter/material.dart';

import '../models/member.dart';
import '../repositories/member_repository.dart';
import '../services/auth_service.dart';
import '../widgets/app_background.dart';

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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to load members: $e')));
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
          title: const Text('Deactivate Member'),
          content: Text('Are you sure you want to deactivate ${member.name}?'),
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
              child: const Text('Deactivate'),
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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${member.name} deactivated')));
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to deactivate member: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
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
                            if (member.mobile != null) Text(member.mobile!),
                            if (member.address != null) Text(member.address!),
                          ],
                        ),
                        isThreeLine:
                            member.mobile != null && member.address != null,
                        trailing: widget.user.isAdmin
                            ? PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showMemberForm(member: member);
                                  } else if (value == 'deactivate') {
                                    _deactivateMember(member);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'deactivate',
                                    child: Text('Deactivate'),
                                  ),
                                ],
                              )
                            : null,
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
              label: const Text('Add Member'),
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
              'No members found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Tap "Add Member" to add your first member.',
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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to save member: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.member != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Member' : 'Add Member'),
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
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
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
                  labelText: 'Mobile',
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
                  labelText: 'Address',
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}
