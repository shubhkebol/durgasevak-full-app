import 'package:flutter/material.dart';

import '../models/member.dart';
import '../repositories/donation_repository.dart';
import '../repositories/member_repository.dart';
import '../services/auth_service.dart';
import '../services/whatsapp_reminder_service.dart';
import '../utils/marathi_constants.dart';
import '../widgets/app_background.dart';
import '../widgets/whatsapp_icon.dart';
import 'members_screen.dart';

class MemberMissedDonationsScreen extends StatefulWidget {
  final Member member;
  final AuthUser user;

  const MemberMissedDonationsScreen({
    super.key,
    required this.member,
    required this.user,
  });

  @override
  State<MemberMissedDonationsScreen> createState() =>
      _MemberMissedDonationsScreenState();
}

class _MemberMonthInfo {
  final int monthNumber;
  final String monthName;
  final int year;
  final bool isPaid;
  final double? amount;
  final String? paymentDate;
  final String? note;

  String get label => '$monthName $year';
  String get monthKey => '$year-${monthNumber.toString().padLeft(2, '0')}';

  const _MemberMonthInfo({
    required this.monthNumber,
    required this.monthName,
    required this.year,
    required this.isPaid,
    this.amount,
    this.paymentDate,
    this.note,
  });
}

class _MemberMissedDonationsScreenState
    extends State<MemberMissedDonationsScreen> {
  final DonationRepository _donationRepository = DonationRepository.instance;
  final MemberRepository _memberRepository = MemberRepository.instance;
  final WhatsAppReminderService _whatsAppService =
      WhatsAppReminderService.instance;

  late Member _currentMember;
  int _selectedYear = DateTime.now().year;

  List<_MemberMonthInfo> _months = [];
  final Set<String> _selectedMissedMonths = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentMember = widget.member;
    _loadMemberData();
  }

  Future<void> _loadMemberData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final updatedMember = await _memberRepository.getMember(
        _currentMember.id!,
      );
      if (updatedMember != null) {
        _currentMember = updatedMember;
      }

      final donations = await _donationRepository.getMemberMonthlyDonations(
        _currentMember.id!,
      );

      final Map<String, Map<String, dynamic>> paidMap = {};
      for (final d in donations) {
        final dateStr = d['date'] as String?;
        if (dateStr != null && dateStr.length >= 7) {
          final key = dateStr.substring(0, 7);
          paidMap[key] = d;
        }
      }

      final List<_MemberMonthInfo> monthList = [];
      final now = DateTime.now();

      for (var m = 1; m <= 12; m++) {
        final key = '$_selectedYear-${m.toString().padLeft(2, '0')}';
        final isPaid = paidMap.containsKey(key);
        final donationData = paidMap[key];

        monthList.add(
          _MemberMonthInfo(
            monthNumber: m,
            monthName: MarathiConstants.getMonthName(m),
            year: _selectedYear,
            isPaid: isPaid,
            amount: (donationData?['amount'] as num?)?.toDouble(),
            paymentDate: donationData?['date'] as String?,
            note: donationData?['note'] as String?,
          ),
        );
      }

      // Pre-select all missed months up to current month (or all if previous year)
      _selectedMissedMonths.clear();
      for (final m in monthList) {
        if (!m.isPaid) {
          final isPastOrCurrent =
              (_selectedYear < now.year) ||
              (_selectedYear == now.year && m.monthNumber <= now.month);
          if (isPastOrCurrent) {
            _selectedMissedMonths.add(m.monthKey);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _months = monthList;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading member monthly data: $e')),
      );
    }
  }

  void _selectAllMissed() {
    setState(() {
      for (final m in _months) {
        if (!m.isPaid) {
          _selectedMissedMonths.add(m.monthKey);
        }
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMissedMonths.clear();
    });
  }

  List<String> _getSelectedMonthLabels() {
    final selected = _months
        .where((m) => _selectedMissedMonths.contains(m.monthKey))
        .map((m) => m.label)
        .toList();
    return selected;
  }

  Future<void> _editMember() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => MemberFormDialog(
        member: _currentMember,
        repository: _memberRepository,
      ),
    );

    if (saved == true && mounted) {
      await _loadMemberData();
    }
  }

  Future<void> _promptAddMobileNumber() async {
    final controller = TextEditingController(text: _currentMember.mobile ?? '');
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('मोबाईल नंबर जोडा'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'व्हॉट्सॲप स्मरणपत्र पाठवण्यासाठी वैध मोबाईल नंबर आवश्यक आहे.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'मोबाईल नंबर',
                    hintText: 'उदा. 9876543210',
                    prefixText: '+91 ',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'मोबाईल नंबर रिक्त असू शकत नाही';
                    }
                    final digits = val.replaceAll(RegExp(r'\D'), '');
                    if (digits.length < 10) {
                      return 'किमान १० अंकी नंबर प्रविष्ट करा';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('रद्द करा'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newMember = Member(
                    id: _currentMember.id,
                    name: _currentMember.name,
                    mobile: controller.text.trim(),
                    address: _currentMember.address,
                    active: _currentMember.active,
                  );
                  await _memberRepository.updateMember(newMember);
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop(true);
                  }
                }
              },
              child: const Text('जतन करा'),
            ),
          ],
        );
      },
    );

    if (updated == true && mounted) {
      await _loadMemberData();
    }
  }

  Future<void> _handleSendWhatsAppReminder() async {
    // 1. Check if mobile number exists
    if (_currentMember.mobile == null ||
        _currentMember.mobile!.trim().isEmpty ||
        !_whatsAppService.isValidPhoneNumber(_currentMember.mobile)) {
      final addNow = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('मोबाईल नंबर आवश्यक आहे'),
          content: Text(
            '${_currentMember.name} यांचा मोबाईल नंबर उपलब्ध नाही. तो आता जोडू इच्छिता का?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('रद्द करा'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('मोबाईल जोडा'),
            ),
          ],
        ),
      );

      if (addNow == true && mounted) {
        await _promptAddMobileNumber();
      }
      return;
    }

    // 2. Check if at least one month is selected
    final selectedLabels = _getSelectedMonthLabels();
    if (selectedLabels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया स्मरणपत्रासाठी किमान एक प्रलंबित महिना निवडा.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 3. Show preview and confirmation sheet
    final totalPending = selectedLabels.length * 100;
    final initialMessage = _whatsAppService.buildReminderMessage(
      memberName: _currentMember.name,
      pendingMonths: selectedLabels,
      monthlyAmount: 100.0,
    );

    if (!mounted) return;

    final messageController = TextEditingController(text: initialMessage);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.viewInsetsOf(bottomSheetCtx).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const WhatsAppIcon(size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'व्हॉट्सॲप स्मरणपत्र',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        _currentMember.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(Icons.phone, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        '+91 ${_currentMember.mobile!}',
                        style: const TextStyle(
                          color: Colors.deepOrangeAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.deepOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'प्रलंबित महिने: ${selectedLabels.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        'एकूण प्रलंबित: ₹$totalPending/-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrangeAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'मेसेज पूर्वावलोकन (संपादनक्षम):',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: messageController,
                  maxLines: 10,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    fillColor: const Color(0xFF121212),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(bottomSheetCtx).pop();

                    final message = messageController.text.trim();
                    final success = await _whatsAppService.sendReminder(
                      phoneNumber: _currentMember.mobile!,
                      message: message,
                    );

                    if (!mounted) return;

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${_currentMember.name} यांच्यासाठी व्हॉट्सॲप सुरू होत आहे...',
                          ),
                          backgroundColor: const Color(0xFF25D366),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'व्हॉट्सॲप उघडता आले नाही. कृपया व्हॉट्सॲप इन्स्टॉल असल्याची खात्री करा.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const WhatsAppIcon(size: 22),
                  label: const Text(
                    'व्हॉट्सॲपवर पाठवा',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectYear() async {
    final currentYear = DateTime.now().year;
    final years = List.generate(10, (i) => currentYear - 5 + i);

    final chosenYear = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('वर्ष निवडा'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: years.length,
            itemBuilder: (context, index) {
              final y = years[index];
              final isSelected = y == _selectedYear;
              return ListTile(
                title: Text(
                  '$y',
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.deepOrange : null,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.deepOrange)
                    : null,
                onTap: () => Navigator.of(ctx).pop(y),
              );
            },
          ),
        ),
      ),
    );

    if (chosenYear != null && chosenYear != _selectedYear && mounted) {
      setState(() {
        _selectedYear = chosenYear;
      });
      await _loadMemberData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final missedCount = _months.where((m) => !m.isPaid).length;
    final paidCount = _months.where((m) => m.isPaid).length;
    final selectedCount = _selectedMissedMonths.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentMember.name),
        actions: [
          if (widget.user.isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Member',
              onPressed: _editMember,
            ),
        ],
      ),
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadMemberData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    _buildMemberProfileCard(),
                    const SizedBox(height: 14),
                    _buildYearSelector(),
                    const SizedBox(height: 12),
                    _buildSummaryRow(paidCount, missedCount),
                    const SizedBox(height: 16),
                    _buildListHeader(missedCount, selectedCount),
                    const SizedBox(height: 8),
                    _buildMonthsList(),
                  ],
                ),
              ),
      ),
      bottomSheet: _buildWhatsAppBottomBar(selectedCount),
    );
  }

  Widget _buildMemberProfileCard() {
    final hasMobile =
        _currentMember.mobile != null &&
        _currentMember.mobile!.trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.deepOrange.withValues(alpha: 0.2),
              child: Text(
                _currentMember.name.isEmpty
                    ? '?'
                    : _currentMember.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrangeAccent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentMember.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasMobile)
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 15, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          '+91 ${_currentMember.mobile!}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    )
                  else
                    widget.user.isAdmin
                        ? InkWell(
                            onTap: _promptAddMobileNumber,
                            borderRadius: BorderRadius.circular(4),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.add_call,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Add Mobile Number',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Text(
                            'No mobile number',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                  if (_currentMember.address != null &&
                      _currentMember.address!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _currentMember.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (widget.user.isAdmin)
              IconButton(
                onPressed: _editMember,
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Edit Member Details',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous Year',
              onPressed: () {
                setState(() {
                  _selectedYear--;
                });
                _loadMemberData();
              },
            ),
            InkWell(
              onTap: _selectYear,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.deepOrangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_selectedYear',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next Year',
              onPressed: () {
                setState(() {
                  _selectedYear++;
                });
                _loadMemberData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(int paidCount, int missedCount) {
    return Row(
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            color: const Color(0xFF1B2B1B),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$paidCount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'जमा महिने',
                    style: TextStyle(fontSize: 12, color: Colors.greenAccent),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            color: const Color(0xFF331B1B),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cancel,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$missedCount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'प्रलंबित महिने',
                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader(int missedCount, int selectedCount) {
    if (!widget.user.isAdmin) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'मासिक देणग्या',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: missedCount > 0
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              missedCount > 0
                  ? '$_selectedYear मध्ये $missedCount महिने बाकी'
                  : '$_selectedYear मध्ये सर्व महिने जमा',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: missedCount > 0 ? Colors.redAccent : Colors.green,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'मासिक देणग्या',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (missedCount > 0)
              Text(
                '$missedCount पैकी $selectedCount प्रलंबित महिने निवडले',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        if (missedCount > 0)
          Row(
            children: [
              TextButton(
                onPressed: selectedCount == missedCount
                    ? _clearSelection
                    : _selectAllMissed,
                child: Text(
                  selectedCount == missedCount ? 'निवड काढा' : 'सर्व निवडा',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMonthsList() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < _months.length; i++) ...[
            _buildMonthTile(_months[i]),
            if (i < _months.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthTile(_MemberMonthInfo info) {
    final isSelected = _selectedMissedMonths.contains(info.monthKey);
    final isAdmin = widget.user.isAdmin;

    return Container(
      color: isAdmin && !info.isPaid && isSelected
          ? Colors.deepOrange.withValues(alpha: 0.08)
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: info.isPaid
            ? const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF1B3B1B),
                child: Icon(Icons.check, size: 20, color: Colors.green),
              )
            : (isAdmin
                  ? Checkbox(
                      value: isSelected,
                      activeColor: Colors.deepOrange,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedMissedMonths.add(info.monthKey);
                          } else {
                            _selectedMissedMonths.remove(info.monthKey);
                          }
                        });
                      },
                    )
                  : const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF331B1B),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                    )),
        title: Text(
          info.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: info.isPaid ? Colors.white70 : Colors.white,
          ),
        ),
        subtitle: info.isPaid
            ? Text(
                info.amount != null
                    ? 'रक्कम: ₹${info.amount!.toStringAsFixed(0)}'
                    : 'जमा',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              )
            : const Text(
                'प्रलंबित: ₹१००/-',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.redAccent,
                ),
              ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: info.isPaid
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            info.isPaid ? 'जमा' : 'बाकी',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: info.isPaid ? Colors.green : Colors.redAccent,
            ),
          ),
        ),
        onTap: (isAdmin && !info.isPaid)
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedMissedMonths.remove(info.monthKey);
                  } else {
                    _selectedMissedMonths.add(info.monthKey);
                  }
                });
              }
            : null,
      ),
    );
  }

  Widget? _buildWhatsAppBottomBar(int selectedCount) {
    if (!widget.user.isAdmin) return null;

    final hasSelection = selectedCount > 0;
    final totalPendingAmount = selectedCount * 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _handleSendWhatsAppReminder,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const WhatsAppIcon(size: 24),
              const SizedBox(width: 10),
              Text(
                hasSelection
                    ? 'व्हॉट्सॲप स्मरणपत्र पाठवा ($selectedCount महिने • ₹$totalPendingAmount/-)'
                    : 'व्हॉट्सॲप स्मरणपत्र पाठवा',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
