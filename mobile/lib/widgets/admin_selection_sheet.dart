import 'package:flutter/material.dart';

import '../models/admin_contact.dart';
import '../repositories/admin_contact_repository.dart';
import '../services/sync_metadata_service.dart';
import '../services/whatsapp_reminder_service.dart';
import 'whatsapp_icon.dart';

class AdminSelectionSheet extends StatefulWidget {
  final String viewerEmail;
  final bool isLoginScreen;

  const AdminSelectionSheet({
    super.key,
    required this.viewerEmail,
    this.isLoginScreen = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String viewerEmail,
    bool isLoginScreen = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminSelectionSheet(
        viewerEmail: viewerEmail,
        isLoginScreen: isLoginScreen,
      ),
    );
  }

  @override
  State<AdminSelectionSheet> createState() => _AdminSelectionSheetState();
}

class _AdminSelectionSheetState extends State<AdminSelectionSheet> {
  final AdminContactRepository _repository = AdminContactRepository();
  List<AdminContact> _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    final contacts = await _repository.getAdminContacts();
    if (mounted) {
      setState(() {
        if (widget.isLoginScreen || widget.viewerEmail.trim().isEmpty) {
          // On login screen: Show only permanent official admins (hide test contact Shubham)
          _admins = contacts.where((c) {
            final name = c.name.trim().toLowerCase();
            final phone = c.mobile.replaceAll(RegExp(r'\D'), '');
            return name != 'shubham' && !phone.endsWith('8390161840');
          }).toList();
        } else {
          // For asking cloud access: Show all admins including Shubham
          _admins = contacts;
        }
        _isLoading = false;
      });
    }
  }

  String _formatPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '+91 ${clean.substring(0, 5)} ${clean.substring(5)}';
    }
    return phone;
  }

  Future<void> _handleAdminContact(AdminContact admin) async {
    final savedName =
        await SyncMetadataService.instance.get('member_contact_name') ?? '';

    if (!mounted) return;

    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _MemberContactDialog(
        admin: admin,
        viewerEmail: widget.viewerEmail,
        initialName: savedName,
      ),
    );

    if (sent == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.orange,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.viewerEmail.trim().isEmpty
                          ? 'अधिकृत ॲडमिन संपर्क'
                          : 'ॲडमिन निवडा',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.viewerEmail.trim().isEmpty
                          ? 'नवीन सदस्य संपर्क व मार्गदर्शन'
                          : 'गुगल ड्राइव्ह परवानगी विनंती पाठवा',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.viewerEmail.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 18,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'तुमचा ईमेल: ${widget.viewerEmail.trim()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Text(
            widget.viewerEmail.trim().isEmpty
                ? 'नवीन सदस्य म्हणून संपर्क साधण्यासाठी खालील ॲडमिन निवडा:'
                : 'परवानगी मागण्यासाठी खालीलपैकी कोणत्याही ॲडमिनशी संपर्क साधा:',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_admins.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('कोणतेही ॲडमिन संपर्क सापडले नाहीत.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _admins.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final admin = _admins[index];
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: admin.isPrimary
                        ? const BorderSide(color: Colors.orange, width: 1.5)
                        : BorderSide(color: Colors.grey.withAlpha(40)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: admin.isPrimary
                              ? Colors.orange.withAlpha(40)
                              : Colors.grey.withAlpha(30),
                          child: Icon(
                            admin.isPrimary ? Icons.shield : Icons.person,
                            color: admin.isPrimary
                                ? Colors.orange
                                : Colors.grey,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      admin.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (admin.isPrimary) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withAlpha(40),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'प्रमुख',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                admin.post,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatPhone(admin.mobile),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _handleAdminContact(admin),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const WhatsAppIcon(size: 16),
                          label: Text(
                            widget.viewerEmail.trim().isNotEmpty
                                ? 'विनंती'
                                : 'संपर्क',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('बंद करा'),
          ),
        ],
      ),
    );
  }
}

class _MemberContactDialog extends StatefulWidget {
  final AdminContact admin;
  final String viewerEmail;
  final String initialName;

  const _MemberContactDialog({
    required this.admin,
    required this.viewerEmail,
    required this.initialName,
  });

  @override
  State<_MemberContactDialog> createState() => _MemberContactDialogState();
}

class _MemberContactDialogState extends State<_MemberContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _messageController;
  bool _isCustomized = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _messageController = TextEditingController(
      text: _buildTemplate(widget.initialName),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _formatPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '+91 ${clean.substring(0, 5)} ${clean.substring(5)}';
    }
    return phone;
  }

  String _buildTemplate(String rawName) {
    final name = rawName.trim().isEmpty ? '[तुमचे पूर्ण नाव]' : rawName.trim();
    if (widget.viewerEmail.trim().isNotEmpty) {
      return 'जय शिवराय ${widget.admin.name},\n\n'
          'मी $name.\n'
          'मी दुर्गसेवक ॲपचा सदस्य असून गुगल ड्राइव्ह बॅकअपच्या व्ह्यूअर परवानगीसाठी संपर्क साधत आहे.\n'
          'माझा ईमेल: ${widget.viewerEmail.trim()}\n\n'
          'कृपया माझ्या या ईमेलला बॅकअप पाहण्याची व्ह्यूअर परवानगी द्यावी.\n\n'
          'धन्यवाद!\n'
          '🚩 दुर्गसेवक परिवार 🚩';
    } else {
      return 'जय शिवराय ${widget.admin.name},\n\n'
          'मी $name.\n'
          'मी नवीन सदस्य म्हणून दुर्गसेवक परिवाराशी संपर्क साधत आहे.\n\n'
          'कृपया मला दुर्गसेवक ॲप आणि परिवाराच्या कार्याबद्दल पुढील माहिती व मार्गदर्शन द्यावे.\n\n'
          'धन्यवाद!\n'
          '🚩 दुर्गसेवक परिवार 🚩';
    }
  }

  void _onNameChanged(String val) {
    if (!_isCustomized) {
      setState(() {
        _messageController.text = _buildTemplate(val);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final enteredName = _nameController.text.trim();
    if (enteredName.isEmpty) return;

    setState(() => _isSending = true);

    // Save member name for future convenience
    await SyncMetadataService.instance.set('member_contact_name', enteredName);

    final message = _messageController.text.trim().isNotEmpty
        ? _messageController.text.trim()
        : _buildTemplate(enteredName);

    final success = await WhatsAppReminderService.openWhatsAppChat(
      phoneNumber: widget.admin.mobile,
      message: message,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (success) {
      Navigator.of(context).pop(true);
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
  }

  @override
  Widget build(BuildContext context) {
    final isDriveRequest = widget.viewerEmail.trim().isNotEmpty;

    return AlertDialog(
      title: const Row(
        children: [
          WhatsAppIcon(size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'ॲडमिनशी संपर्क साधा',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.orange.withAlpha(40),
                      child: const Icon(
                        Icons.person,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.admin.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${widget.admin.post} • ${_formatPhone(widget.admin.mobile)}',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: widget.initialName.isEmpty,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'आपले पूर्ण नाव *',
                  hintText: 'उदा. राहुल पाटील',
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: Colors.orange,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  helperText: isDriveRequest
                      ? 'परवानगीसाठी आपले नाव आवश्यक आहे'
                      : 'नवीन सदस्य म्हणून आपले नाव प्रविष्ट करा',
                ),
                onChanged: _onNameChanged,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'कृपया आपले पूर्ण नाव प्रविष्ट करा';
                  }
                  if (val.trim().length < 2) {
                    return 'किमान २ अक्षरी नाव प्रविष्ट करा';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'व्हॉट्सॲप मेसेज पूर्वावलोकन (संपादनक्षम):',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageController,
                maxLines: 6,
                style: const TextStyle(fontSize: 13, height: 1.4),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.black26,
                ),
                onChanged: (_) => _isCustomized = true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('रद्द करा'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _isSending ? null : _submit,
          icon: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const WhatsAppIcon(size: 18),
          label: const Text(
            'व्हॉट्सॲपवर पाठवा',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
