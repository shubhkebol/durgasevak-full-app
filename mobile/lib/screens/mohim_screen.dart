import 'package:flutter/material.dart';

import '../models/mohim.dart';
import '../repositories/mohim_repository.dart';
import '../services/auth_service.dart';
import '../widgets/app_background.dart';
import 'mohim_attendance_screen.dart';

class MohimScreen extends StatefulWidget {
  final AuthUser user;

  const MohimScreen({super.key, required this.user});

  @override
  State<MohimScreen> createState() => _MohimScreenState();
}

class _MohimScreenState extends State<MohimScreen> {
  final MohimRepository _repository = MohimRepository.instance;

  final TextEditingController _searchController = TextEditingController();

  List<Mohim> _mohims = [];

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
      final mohims = await _repository.getActiveMohims(
        search: _searchController.text,
      );

      mohims.sort((a, b) {
        final dateA = DateTime.tryParse(a.startDate ?? '');
        final dateB = DateTime.tryParse(b.startDate ?? '');

        if (dateA == null && dateB == null) {
          return (b.id ?? 0).compareTo(a.id ?? 0);
        }

        if (dateA == null) {
          return 1;
        }

        if (dateB == null) {
          return -1;
        }

        final dateCompare = dateB.compareTo(dateA);

        if (dateCompare != 0) {
          return dateCompare;
        }

        return (b.id ?? 0).compareTo(a.id ?? 0);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _mohims = mohims;
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
        SnackBar(content: Text('मोहीम माहिती लोड करण्यात अडचण आली: $e')),
      );
    }
  }

  Future<void> _openAttendance(Mohim mohim) async {
    if (mohim.id == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MohimAttendanceScreen(
          mohimId: mohim.id!,
          mohimName: mohim.name,
          startDate: mohim.startDate,
          endDate: mohim.endDate,
          description: mohim.description,
          user: widget.user,
        ),
      ),
    );
  }

  Future<void> _showMohimForm({Mohim? mohim}) async {
    if (!widget.user.isAdmin) {
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return MohimFormDialog(mohim: mohim, repository: _repository);
      },
    );

    if (result == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _confirmDeactivate(Mohim mohim) async {
    if (!widget.user.isAdmin || mohim.id == null) {
      return;
    }

    final shouldDeactivate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('मोहीम निष्क्रिय करा'),
          content: Text(
            'तुम्हाला खात्री आहे की '
            '"${mohim.name}" ही मोहीम निष्क्रिय करायची आहे?',
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

    if (shouldDeactivate != true) {
      return;
    }

    try {
      await _repository.deactivateMohim(mohim.id!);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('मोहीम निष्क्रिय केली')));

      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('मोहीम निष्क्रिय करण्यात अडचण आली: $e')),
      );
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

  String _dateRange(Mohim mohim) {
    final start = _formatDate(mohim.startDate);
    final end = _formatDate(mohim.endDate);

    if (start.isEmpty && end.isEmpty) {
      return '';
    }

    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }

    if (start.isNotEmpty) {
      return 'सुरू: $start';
    }

    return 'समाप्ती: $end';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('मोहीम')),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'मोहीम शोधा',
                  hintText: 'नाव किंवा वर्णन',
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
            const SizedBox(height: 4),
            Expanded(child: _buildMohimList()),
          ],
        ),
      ),
      floatingActionButton: widget.user.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showMohimForm(),
              icon: const Icon(Icons.add),
              label: const Text('मोहीम जोडा'),
            )
          : null,
    );
  }

  Widget _buildMohimList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mohims.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Icon(Icons.campaign, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Center(
              child: Text(
                'कोणतीही मोहीम आढळली नाही',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'सुरुवात करण्यासाठी नवीन मोहीम जोडा.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _mohims.length,
        itemBuilder: (context, index) {
          final mohim = _mohims[index];
          final range = _dateRange(mohim);

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _openAttendance(mohim),
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(child: Icon(Icons.campaign)),
              title: Text(
                mohim.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (range.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.calendar_today, size: 15),
                          const SizedBox(width: 6),
                          Expanded(child: Text(range)),
                        ],
                      ),
                    if (range.isNotEmpty &&
                        mohim.description != null &&
                        mohim.description!.trim().isNotEmpty)
                      const SizedBox(height: 6),
                    if (mohim.description != null &&
                        mohim.description!.trim().isNotEmpty)
                      Text(
                        mohim.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.fact_check_outlined, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'हजेरी पाहण्यासाठी टॅप करा',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chevron_right),
                  if (widget.user.isAdmin)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showMohimForm(mohim: mohim);
                        } else if (value == 'deactivate') {
                          _confirmDeactivate(mohim);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 12),
                              Text('संपादित करा'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'deactivate',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline),
                              SizedBox(width: 12),
                              Text('निष्क्रिय करा'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MohimFormDialog extends StatefulWidget {
  final Mohim? mohim;
  final MohimRepository repository;

  const MohimFormDialog({super.key, this.mohim, required this.repository});

  @override
  State<MohimFormDialog> createState() => _MohimFormDialogState();
}

class _MohimFormDialogState extends State<MohimFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSaving = false;

  bool get _isEditing => widget.mohim != null;

  @override
  void initState() {
    super.initState();

    final mohim = widget.mohim;

    _nameController = TextEditingController(text: mohim?.name ?? '');

    _descriptionController = TextEditingController(
      text: mohim?.description ?? '',
    );

    if (mohim?.startDate != null) {
      _startDate = DateTime.tryParse(mohim!.startDate!);
    }

    if (mohim?.endDate != null) {
      _endDate = DateTime.tryParse(mohim!.endDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() {
        _startDate = selected;

        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() {
        _endDate = selected;
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया मोहिमेचे नाव प्रविष्ट करा')),
      );

      return;
    }

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'समाप्ती तारीख सुरुवातीच्या तारखेच्या आधी असू शकत नाही',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    final mohim = Mohim(
      id: widget.mohim?.id,
      name: name,
      startDate: _startDate?.toIso8601String(),
      endDate: _endDate?.toIso8601String(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      active: true,
    );

    try {
      if (_isEditing) {
        await widget.repository.updateMohim(mohim);
      } else {
        await widget.repository.addMohim(mohim);
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
      ).showSnackBar(SnackBar(content: Text('मोहीम जतन करण्यात अडचण आली: $e')));
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'निवडलेली नाही';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _dateSelector({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: _isSaving ? null : onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        child: Text(_formatDate(date)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'मोहीम संपादित करा' : 'मोहीम जोडा'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'मोहिमेचे नाव',
                hintText: 'उदा. दुर्ग स्वच्छता मोहीम',
                prefixIcon: Icon(Icons.campaign),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _dateSelector(
              label: 'सुरुवात तारीख',
              date: _startDate,
              onTap: _selectStartDate,
              icon: Icons.calendar_today,
            ),
            const SizedBox(height: 16),
            _dateSelector(
              label: 'समाप्ती तारीख',
              date: _endDate,
              onTap: _selectEndDate,
              icon: Icons.event,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              enabled: !_isSaving,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'वर्णन',
                hintText: 'ऐच्छिक',
                border: OutlineInputBorder(),
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
              : Text(_isEditing ? 'अपडेट करा' : 'जतन करा'),
        ),
      ],
    );
  }
}
