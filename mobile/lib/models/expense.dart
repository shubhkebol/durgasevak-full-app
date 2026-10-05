class Expense {
  final int? id;
  final double amount;
  final String date;
  final String? category;
  final String? note;
  final bool active;

  const Expense({
    this.id,
    required this.amount,
    required this.date,
    this.category,
    this.note,
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date,
      'category': category,
      'note': note,
      'active': active ? 1 : 0,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      category: map['category'] as String?,
      note: map['note'] as String?,
      active: (map['active'] as int? ?? 1) == 1,
    );
  }
}
