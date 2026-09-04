class Committee {
  final int? id;
  final String position;
  final int memberId;
  final String memberName;
  final String? mobile;
  final String createdAt;
  final String updatedAt;

  const Committee({
    this.id,
    required this.position,
    required this.memberId,
    required this.memberName,
    this.mobile,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Committee.fromMap(Map<String, dynamic> map) {
    return Committee(
      id: map['id'] as int?,
      position: map['position'] as String,
      memberId: map['member_id'] as int,
      memberName: map['member_name'] as String,
      mobile: map['mobile'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'position': position,
      'member_id': memberId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
