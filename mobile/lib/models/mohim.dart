class Mohim {
  final int? id;
  final String name;
  final String? startDate;
  final String? endDate;
  final String? description;
  final bool active;

  const Mohim({
    this.id,
    required this.name,
    this.startDate,
    this.endDate,
    this.description,
    required this.active,
  });

  factory Mohim.fromMap(Map<String, dynamic> map) {
    return Mohim(
      id: map['id'] as int?,
      name: map['name'] as String,
      startDate: map['start_date'] as String?,
      endDate: map['end_date'] as String?,
      description: map['description'] as String?,
      active: (map['active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
      'description': description,
      'active': active ? 1 : 0,
    };
  }

  Mohim copyWith({
    int? id,
    String? name,
    String? startDate,
    String? endDate,
    String? description,
    bool? active,
  }) {
    return Mohim(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      active: active ?? this.active,
    );
  }
}
