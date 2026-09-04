class MohimAttendance {
  final int? id;
  final int mohimId;
  final int? memberId;
  final String? visitorName;
  final String createdAt;

  const MohimAttendance({
    this.id,
    required this.mohimId,
    this.memberId,
    this.visitorName,
    required this.createdAt,
  });

  bool get isMember {
    return memberId != null;
  }

  bool get isOtherVisitor {
    return memberId == null &&
        visitorName != null &&
        visitorName!.trim().isNotEmpty;
  }

  factory MohimAttendance.fromMap(Map<String, dynamic> map) {
    return MohimAttendance(
      id: map['id'] as int?,
      mohimId: map['mohim_id'] as int,
      memberId: map['member_id'] as int?,
      visitorName: map['visitor_name'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'mohim_id': mohimId,
      'member_id': memberId,
      'visitor_name': visitorName,
      'created_at': createdAt,
    };
  }
}
