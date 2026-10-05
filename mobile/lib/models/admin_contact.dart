class AdminContact {
  final int? id;
  final String name;
  final String post;
  final String mobile;
  final bool isPrimary;

  const AdminContact({
    this.id,
    required this.name,
    required this.post,
    required this.mobile,
    this.isPrimary = false,
  });

  AdminContact copyWith({
    int? id,
    String? name,
    String? post,
    String? mobile,
    bool? isPrimary,
  }) {
    return AdminContact(
      id: id ?? this.id,
      name: name ?? this.name,
      post: post ?? this.post,
      mobile: mobile ?? this.mobile,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'post': post,
      'mobile': mobile,
      'is_primary': isPrimary ? 1 : 0,
    };
  }

  factory AdminContact.fromMap(Map<String, dynamic> map) {
    return AdminContact(
      id: map['id'] as int?,
      name: map['name'] as String,
      post: map['post'] as String,
      mobile: map['mobile'] as String,
      isPrimary: (map['is_primary'] as int? ?? 0) == 1,
    );
  }
}
