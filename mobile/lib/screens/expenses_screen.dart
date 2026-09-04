import 'package:flutter/material.dart';

import '../models/expense.dart';

import '../repositories/expense_repository.dart';

import '../services/auth_service.dart';

import '../widgets/app_background.dart';

class ExpensesScreen extends StatefulWidget {
  final AuthUser user;

  const ExpensesScreen({super.key, required this.user});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseRepository _repository = ExpenseRepository.instance;

  final TextEditingController _searchController = TextEditingController();

  List<Expense> _expenses = [];

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
      final expenses = await _repository.getActiveExpenses(
        search: _searchController.text,
      );

      final total = await _repository.getTotalActiveExpenses();

      expenses.sort((a, b) {
        final dateA = DateTime.tryParse(a.date);
        final dateB = DateTime.tryParse(b.date);

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
        _expenses = expenses;

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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to load expenses: $e')));
    }
  }

  Future<void> _showExpenseForm({Expense? expense}) async {
    if (!widget.user.isAdmin) {
      return;
    }

    final result = await showDialog<bool>(
      context: context,

      builder: (_) {
        return ExpenseFormDialog(expense: expense, repository: _repository);
      },
    );

    if (result == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _confirmDeactivate(Expense expense) async {
    if (!widget.user.isAdmin || expense.id == null) {
      return;
    }

    final shouldDeactivate = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate Expense'),

          content: Text(
            'Are you sure you want to deactivate '
            'this expense of '
            '₹${expense.amount.toStringAsFixed(2)}?',
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
      await _repository.deactivateExpense(expense.id!);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Expense deactivated')));

      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to deactivate expense: $e')),
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
      appBar: AppBar(title: const Text('Expenses')),

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
                  labelText: 'Search expenses',

                  hintText: 'Category, amount or note',

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
                      const CircleAvatar(child: Icon(Icons.receipt_long)),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Text(
                              'Total Expenses',

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

            Expanded(child: _buildExpenseList()),
          ],
        ),
      ),

      floatingActionButton: widget.user.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showExpenseForm(),

              icon: const Icon(Icons.add),

              label: const Text('Add Expense'),
            )
          : null,
    );
  }

  Widget _buildExpenseList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_expenses.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          children: const [
            SizedBox(height: 100),

            Icon(Icons.receipt_long, size: 64, color: Colors.grey),

            SizedBox(height: 16),

            Center(
              child: Text('No expenses found', style: TextStyle(fontSize: 18)),
            ),

            SizedBox(height: 8),

            Center(child: Text('Add an expense to get started.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,

      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),

        itemCount: _expenses.length,

        itemBuilder: (context, index) {
          final expense = _expenses[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 10),

            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.receipt_long)),

              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      expense.category?.trim().isNotEmpty == true
                          ? expense.category!
                          : 'Expense',

                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                  Text(
                    '₹${expense.amount.toStringAsFixed(2)}',

                    style: const TextStyle(
                      fontSize: 16,

                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const SizedBox(height: 4),

                  Text(_formatDate(expense.date)),

                  if (expense.note != null && expense.note!.trim().isNotEmpty)
                    Text(
                      expense.note!,

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),

              trailing: widget.user.isAdmin
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showExpenseForm(expense: expense);
                        } else if (value == 'deactivate') {
                          _confirmDeactivate(expense);
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
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class ExpenseFormDialog extends StatefulWidget {
  final Expense? expense;

  final ExpenseRepository repository;

  const ExpenseFormDialog({super.key, this.expense, required this.repository});

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  late final TextEditingController _amountController;

  late final TextEditingController _categoryController;

  late final TextEditingController _noteController;

  DateTime _selectedDate = DateTime.now();

  bool _isSaving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();

    final expense = widget.expense;

    _amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );

    _categoryController = TextEditingController(text: expense?.category ?? '');

    _noteController = TextEditingController(text: expense?.note ?? '');

    if (expense != null) {
      final parsedDate = DateTime.tryParse(expense.date);

      if (parsedDate != null) {
        _selectedDate = parsedDate;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();

    _categoryController.dispose();

    _noteController.dispose();

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
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount')),
      );

      return;
    }

    final category = _categoryController.text.trim();

    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense category')),
      );

      return;
    }

    setState(() {
      _isSaving = true;
    });

    final expense = Expense(
      id: widget.expense?.id,

      amount: amount,

      date: _selectedDate.toIso8601String(),

      category: category,

      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),

      active: true,
    );

    try {
      if (_isEditing) {
        await widget.repository.updateExpense(expense);
      } else {
        await widget.repository.addExpense(expense);
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
          .showSnackBar(SnackBar(content: Text('Unable to save expense: $e')));
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
      title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            TextField(
              controller: _categoryController,

              enabled: !_isSaving,

              textCapitalization: TextCapitalization.words,

              decoration: const InputDecoration(
                labelText: 'Category',

                hintText: 'e.g. Travel, Food, Event',

                prefixIcon: Icon(Icons.category_outlined),

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

              enabled: !_isSaving,

              maxLines: 3,

              decoration: const InputDecoration(
                labelText: 'Note',

                hintText: 'Optional',

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
}
