import 'package:flutter/material.dart';

import '../models/donation.dart';

import '../models/member.dart';

import '../repositories/donation_repository.dart';

import '../repositories/member_repository.dart';

import '../services/auth_service.dart';

import '../widgets/app_background.dart';

class DonationsScreen extends StatefulWidget {
  final AuthUser user;

  const DonationsScreen({super.key, required this.user});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  final DonationRepository _donationRepository = DonationRepository.instance;

  final MemberRepository _memberRepository = MemberRepository.instance;

  final TextEditingController _searchController = TextEditingController();

  List<Donation> _donations = [];

  List<Member> _members = [];

  double _total = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final donations = await _donationRepository.getActiveDonations(
        search: _searchController.text,
      );

      final members = await _memberRepository.getActiveMembers();

      final total = await _donationRepository.getTotalActiveDonations();

      if (!mounted) {
        return;
      }

      setState(() {
        _donations = donations;

        _members = members;

        _total = total;

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
      ).showSnackBar(SnackBar(content: Text('Unable to load donations: $e')));
    }
  }

  Future<void> _showDonationForm({Donation? donation}) async {
    if (!widget.user.isAdmin) {
      return;
    }

    final result = await showDialog<bool>(
      context: context,

      builder: (_) {
        return DonationFormDialog(
          donation: donation,

          members: _members,

          repository: _donationRepository,
        );
      },
    );

    if (result == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _confirmDeactivate(Donation donation) async {
    if (!widget.user.isAdmin || donation.id == null) {
      return;
    }

    final shouldDeactivate = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate Donation'),

          content: Text(
            'Are you sure you want to deactivate '
            'this donation of '
            '₹${donation.amount.toStringAsFixed(2)}?',
          ),

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

    if (shouldDeactivate != true) {
      return;
    }

    try {
      await _donationRepository.deactivateDonation(donation.id!);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Donation deactivated')));

      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to deactivate donation: $e')),
      );
    }
  }

  String _formatDate(String date) {
    final parsed = DateTime.tryParse(date);

    if (parsed == null) {
      return date;
    }

    return '${parsed.day.toString().padLeft(2, '0')}/'
        '${parsed.month.toString().padLeft(2, '0')}/'
        '${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donations')),

      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),

              child: TextField(
                controller: _searchController,

                onChanged: (_) {
                  _loadData();
                },

                decoration: InputDecoration(
                  labelText: 'Search donations',

                  hintText: 'Donor, amount or note',

                  prefixIcon: const Icon(Icons.search),

                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),

                          onPressed: () {
                            _searchController.clear();

                            _loadData();
                          },
                        ),

                  border: const OutlineInputBorder(),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.currency_rupee)),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Text(
                              'Total Donations',

                              style: TextStyle(fontSize: 14),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              '₹${_total.toStringAsFixed(2)}',

                              style: const TextStyle(
                                fontSize: 24,

                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            Expanded(child: _buildDonationList()),
          ],
        ),
      ),

      floatingActionButton: widget.user.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showDonationForm(),

              icon: const Icon(Icons.add),

              label: const Text('Add Donation'),
            )
          : null,
    );
  }

  Widget _buildDonationList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_donations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          children: const [
            SizedBox(height: 100),

            Icon(Icons.currency_rupee, size: 64, color: Colors.grey),

            SizedBox(height: 16),

            Center(
              child: Text('No donations found', style: TextStyle(fontSize: 18)),
            ),

            SizedBox(height: 8),

            Center(child: Text('Add a donation to get started.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,

      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),

        itemCount: _donations.length,

        itemBuilder: (context, index) {
          final donation = _donations[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 10),

            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  donation.isMemberDonation ? Icons.person : Icons.business,
                ),
              ),

              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      donation.displayDonorName,

                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                  if (donation.monthlyDonation)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),

                      child: Chip(
                        label: Text('Monthly', style: TextStyle(fontSize: 11)),

                        visualDensity: VisualDensity.compact,

                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),

              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const SizedBox(height: 4),

                  Text(
                    donation.isMemberDonation
                        ? 'Member • ${_formatDate(donation.date)}'
                        : 'Other Donor • ${_formatDate(donation.date)}',
                  ),

                  if (donation.note != null && donation.note!.trim().isNotEmpty)
                    Text(
                      donation.note!,

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),

              trailing: widget.user.isAdmin
                  ? Row(
                      mainAxisSize: MainAxisSize.min,

                      children: [
                        Text(
                          '₹${donation.amount.toStringAsFixed(2)}',

                          style: const TextStyle(
                            fontSize: 16,

                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showDonationForm(donation: donation);
                            } else if (value == 'deactivate') {
                              _confirmDeactivate(donation);
                            }
                          },

                          itemBuilder: (_) => const [
                            PopupMenuItem<String>(
                              value: 'edit',

                              child: Row(
                                children: [
                                  Icon(Icons.edit),

                                  SizedBox(width: 12),

                                  Text('Edit'),
                                ],
                              ),
                            ),

                            PopupMenuItem<String>(
                              value: 'deactivate',

                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline),

                                  SizedBox(width: 12),

                                  Text('Deactivate'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Text(
                      '₹${donation.amount.toStringAsFixed(2)}',

                      style: const TextStyle(
                        fontSize: 16,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class DonationFormDialog extends StatefulWidget {
  final Donation? donation;

  final List<Member> members;

  final DonationRepository repository;

  const DonationFormDialog({
    super.key,

    this.donation,

    required this.members,

    required this.repository,
  });

  @override
  State<DonationFormDialog> createState() => _DonationFormDialogState();
}

class _DonationFormDialogState extends State<DonationFormDialog> {
  late final TextEditingController _amountController;

  late final TextEditingController _noteController;

  late final TextEditingController _donorNameController;

  String _donorType = 'member';

  int? _selectedMemberId;

  DateTime _selectedDate = DateTime.now();

  bool _monthlyDonation = false;

  bool _isSaving = false;

  bool get _isEditing => widget.donation != null;

  @override
  void initState() {
    super.initState();

    final donation = widget.donation;

    _amountController = TextEditingController(
      text: donation == null ? '' : donation.amount.toStringAsFixed(2),
    );

    _noteController = TextEditingController(text: donation?.note ?? '');

    _donorNameController = TextEditingController(
      text: donation?.donorName ?? '',
    );

    _donorType = donation?.donorType ?? 'member';

    _selectedMemberId = donation?.memberId;

    _monthlyDonation = donation?.monthlyDonation ?? false;

    if (donation != null) {
      final parsedDate = DateTime.tryParse(donation.date);

      if (parsedDate != null) {
        _selectedDate = parsedDate;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();

    _noteController.dispose();

    _donorNameController.dispose();

    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,

      initialDate: _selectedDate,

      firstDate: DateTime(2000),

      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedDate = selected;
      });

      if (_monthlyDonation) {
        _updateMonthlyNote();
      }
    }
  }

  Future<void> _selectMember() async {
    final selectedMember = await showDialog<Member?>(
      context: context,

      builder: (dialogContext) {
        return MemberSearchDialog(
          members: widget.members,

          selectedMemberId: _selectedMemberId,
        );
      },
    );

    if (selectedMember == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMemberId = selectedMember.id;
    });
  }

  String _getMonthName(int month) {
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

  String _monthlyDonationNote() {
    return 'Monthly donation - '
        '${_getMonthName(_selectedDate.month)} '
        '${_selectedDate.year}';
  }

  void _updateMonthlyNote() {
    _noteController.text = _monthlyDonationNote();

    _noteController.selection = TextSelection.fromPosition(
      TextPosition(offset: _noteController.text.length),
    );
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    if (_donorType == 'member' && _selectedMemberId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a member')));

      return;
    }

    if (_donorType == 'other' && _donorNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter donor name')));

      return;
    }

    final amountText = _amountController.text.trim();

    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid donation amount')),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    final donation = Donation(
      id: widget.donation?.id,

      memberId: _donorType == 'member' ? _selectedMemberId : null,

      donorType: _donorType,

      donorName: _donorType == 'other'
          ? _donorNameController.text.trim()
          : null,

      amount: amount,

      date: _selectedDate.toIso8601String(),

      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),

      monthlyDonation: _donorType == 'member' ? _monthlyDonation : false,

      active: true,
    );

    try {
      if (_isEditing) {
        await widget.repository.updateDonation(donation);
      } else {
        await widget.repository.addDonation(donation);
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
          .showSnackBar(SnackBar(content: Text('Unable to save donation: $e')));
    }
  }

  String _formatSelectedDate() {
    return '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/'
        '${_selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Donation' : 'Add Donation'),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            DropdownButtonFormField<String>(
              initialValue: _donorType,

              decoration: const InputDecoration(
                labelText: 'Donor Category',

                border: OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem<String>(
                  value: 'member',

                  child: Text('Member'),
                ),

                DropdownMenuItem<String>(
                  value: 'other',

                  child: Text('Other Donor'),
                ),
              ],

              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }

                      setState(() {
                        _donorType = value;

                        if (value == 'member') {
                          _donorNameController.clear();
                        } else {
                          _selectedMemberId = null;

                          _monthlyDonation = false;
                        }
                      });
                    },
            ),

            const SizedBox(height: 16),

            if (_donorType == 'member') ...[
              InkWell(
                onTap: _isSaving ? null : _selectMember,

                borderRadius: BorderRadius.circular(4),

                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Member',

                    prefixIcon: Icon(Icons.search),

                    border: OutlineInputBorder(),
                  ),

                  child: Text(
                    _selectedMemberId == null
                        ? 'Search and select member'
                        : _getSelectedMemberName(),

                    style: TextStyle(
                      color: _selectedMemberId == null
                          ? Colors.grey.shade700
                          : null,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              CheckboxListTile(
                value: _monthlyDonation,

                contentPadding: EdgeInsets.zero,

                title: const Text('Monthly Donation'),

                subtitle: const Text(
                  'Automatically set note for the selected month',
                ),

                controlAffinity: ListTileControlAffinity.leading,

                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _monthlyDonation = value ?? false;

                          if (_monthlyDonation) {
                            _updateMonthlyNote();
                          } else {
                            _noteController.clear();
                          }
                        });
                      },
              ),
            ],

            if (_donorType == 'other')
              TextField(
                controller: _donorNameController,

                enabled: !_isSaving,

                textCapitalization: TextCapitalization.words,

                decoration: const InputDecoration(
                  labelText: 'Donor Name',

                  hintText: 'Enter person or organization name',

                  prefixIcon: Icon(Icons.person_outline),

                  border: OutlineInputBorder(),
                ),
              ),

            const SizedBox(height: 16),

            TextField(
              controller: _amountController,

              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),

              enabled: !_isSaving,

              decoration: const InputDecoration(
                labelText: 'Amount',

                prefixText: '₹ ',

                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            InkWell(
              onTap: _isSaving ? null : _selectDate,

              borderRadius: BorderRadius.circular(4),

              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',

                  prefixIcon: Icon(Icons.calendar_today),

                  border: OutlineInputBorder(),
                ),

                child: Text(_formatSelectedDate()),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _noteController,

              enabled: !_isSaving && !_monthlyDonation,

              maxLines: 3,

              decoration: InputDecoration(
                labelText: 'Note',

                hintText: _monthlyDonation
                    ? 'Automatically generated'
                    : 'Optional',

                border: const OutlineInputBorder(),
              ),
            ),
          ],
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
              : Text(_isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }

  String _getSelectedMemberName() {
    for (final member in widget.members) {
      if (member.id == _selectedMemberId) {
        return member.name;
      }
    }

    return 'Search and select member';
  }
}

class MemberSearchDialog extends StatefulWidget {
  final List<Member> members;

  final int? selectedMemberId;

  const MemberSearchDialog({
    super.key,

    required this.members,

    this.selectedMemberId,
  });

  @override
  State<MemberSearchDialog> createState() => _MemberSearchDialogState();
}

class _MemberSearchDialogState extends State<MemberSearchDialog> {
  final TextEditingController _searchController = TextEditingController();

  List<Member> _filteredMembers = [];

  @override
  void initState() {
    super.initState();

    _filteredMembers = List<Member>.from(widget.members);
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  void _search(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List<Member>.from(widget.members);
      } else {
        _filteredMembers = widget.members.where((member) {
          return member.name.toLowerCase().contains(query) ||
              (member.mobile ?? '').toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Member'),

      content: SizedBox(
        width: double.maxFinite,

        height: 420,

        child: Column(
          children: [
            TextField(
              controller: _searchController,

              autofocus: true,

              onChanged: _search,

              decoration: InputDecoration(
                labelText: 'Search member',

                hintText: 'Name or mobile number',

                prefixIcon: const Icon(Icons.search),

                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),

                        onPressed: () {
                          _searchController.clear();

                          _search('');
                        },
                      ),

                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: _filteredMembers.isEmpty
                  ? const Center(child: Text('No members found'))
                  : ListView.builder(
                      itemCount: _filteredMembers.length,

                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];

                        final isSelected = member.id == widget.selectedMemberId;

                        String initial = '?';

                        final name = member.name.trim();

                        if (name.isNotEmpty) {
                          initial = name.substring(0, 1).toUpperCase();
                        }

                        return ListTile(
                          leading: CircleAvatar(child: Text(initial)),

                          title: Text(member.name),

                          subtitle:
                              member.mobile == null ||
                                  member.mobile!.trim().isEmpty
                              ? null
                              : Text(member.mobile!),

                          trailing: isSelected
                              ? const Icon(Icons.check_circle)
                              : null,

                          onTap: () {
                            Navigator.of(context).pop(member);
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

          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
