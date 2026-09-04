class Member {
  final int? id;
  final String name;
  final String? mobile;
  final String? address;
  final bool active;

  const Member({
    this.id,
    required this.name,
    this.mobile,
    this.address,
    this.active = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'address': address,
      'active': active ? 1 : 0,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as int?,
      name: map['name'] as String,
      mobile: map['mobile'] as String?,
      address: map['address'] as String?,
      active: (map['active'] as int? ?? 1) == 1,
    );
  }
}
