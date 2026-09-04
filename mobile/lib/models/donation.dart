class Donation {
  final int? id;
  final int? memberId;
  final String? memberName;

  final String donorType;
  final String? donorName;

  final double amount;
  final String date;
  final String? note;

  final bool monthlyDonation;
  final bool active;

  const Donation({
    this.id,
    this.memberId,
    this.memberName,
    this.donorType = 'member',
    this.donorName,
    required this.amount,
    required this.date,
    this.note,
    this.monthlyDonation = false,
    this.active = true,
  });

  bool get isMemberDonation => donorType == 'member';

  bool get isOtherDonation => donorType == 'other';

  String get displayDonorName {
    if (isMemberDonation) {
      return memberName ?? 'Member';
    }

    return donorName ?? 'Other Donor';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'member_id': memberId,
      'donor_type': donorType,
      'donor_name': donorName,
      'amount': amount,
      'date': date,
      'note': note,
      'monthly_donation': monthlyDonation ? 1 : 0,
      'active': active ? 1 : 0,
    };
  }

  factory Donation.fromMap(Map<String, dynamic> map) {
    return Donation(
      id: map['id'] as int?,
      memberId: map['member_id'] as int?,
      memberName: map['member_name'] as String?,
      donorType:
          (map['donor_type'] as String?) ?? 'member',
      donorName: map['donor_name'] as String?,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      note: map['note'] as String?,
      monthlyDonation:
          (map['monthly_donation'] as int? ?? 0) == 1,
      active:
          (map['active'] as int? ?? 1) == 1,
    );
  }
}