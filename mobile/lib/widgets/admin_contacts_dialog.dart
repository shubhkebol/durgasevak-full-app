import 'package:flutter/material.dart';

import '../models/admin_contact.dart';
import '../repositories/admin_contact_repository.dart';

class AdminContactsDialog extends StatefulWidget {
  const AdminContactsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AdminContactsDialog(),
    );
  }

  @override
  State<AdminContactsDialog> createState() => _AdminContactsDialogState();
}

class _AdminContactsDialogState extends State<AdminContactsDialog> {
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
        _admins = contacts;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddEditDialog([AdminContact? existing]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final postController = TextEditingController(text: existing?.post ?? '');
    final mobileController = TextEditingController(
      text: existing?.mobile ?? '',
    );
    bool isPrimary = existing?.isPrimary ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'नवीन ॲडमिन जोडा' : 'ॲडमिन संपादन करा',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'ॲडमिनचे नाव',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: postController,
                  decoration: const InputDecoration(
                    labelText: 'पद / जबाबदारी (उदा. अध्यक्ष / सचिव)',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'व्हॉट्सॲप मोबाईल नंबर (१० अंक)',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isPrimary,
                  title: const Text('प्रमुख ॲडमिन म्हणून सेट करा'),
                  onChanged: (val) {
                    setDialogState(() {
                      isPrimary = val ?? false;
                    });
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
              onPressed: () {
                final name = nameController.text.trim();
                final mobile = mobileController.text.trim();

                if (name.isEmpty || mobile.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('कृपया नाव आणि मोबाईल नंबर प्रविष्ट करा'),
                    ),
                  );
                  return;
                }
                Navigator.of(dialogCtx).pop(true);
              },
              child: const Text('जतन करा'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final contact = AdminContact(
        id: existing?.id,
        name: nameController.text.trim(),
        post: postController.text.trim().isEmpty
            ? 'ॲडमिन'
            : postController.text.trim(),
        mobile: mobileController.text.trim(),
        isPrimary: isPrimary,
      );

      if (existing == null) {
        await _repository.addAdminContact(contact);
      } else {
        await _repository.updateAdminContact(contact);
      }

      if (isPrimary && contact.id != null) {
        await _repository.setPrimaryAdmin(contact.id!);
      }

      await _loadAdmins();
    }
  }

  Future<void> _deleteAdmin(AdminContact admin) async {
    if (admin.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ॲडमिन काढायचा?'),
        content: Text(
          '${admin.name} यांना ॲडमिन संपर्क यादीतून काढायचे आहे का?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('नाही'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('काढून टाका'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteAdminContact(admin.id!);
      await _loadAdmins();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.admin_panel_settings, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'अधिकृत ॲडमिन संपर्क यादी',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              )
            : _admins.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('कोणतेही ॲडमिन संपर्क उपलब्ध नाहीत.'),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _admins.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final admin = _admins[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: admin.isPrimary
                          ? Colors.orange.withAlpha(40)
                          : Colors.grey.withAlpha(30),
                      child: Icon(
                        admin.isPrimary ? Icons.shield : Icons.person,
                        color: admin.isPrimary ? Colors.orange : Colors.grey,
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            admin.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                              borderRadius: BorderRadius.circular(4),
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
                    subtitle: Text('${admin.post} • ${admin.mobile}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          tooltip: 'संपादन',
                          onPressed: () => _showAddEditDialog(admin),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          tooltip: 'हटवा',
                          onPressed: () => _deleteAdmin(admin),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('नवीन ॲडमिन जोडा'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('पूर्ण झाले'),
        ),
      ],
    );
  }
}
