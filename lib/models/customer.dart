/// Hạng thành viên.
enum MemberTier { silver, gold, platinum }

extension MemberTierX on MemberTier {
  String get label {
    switch (this) {
      case MemberTier.silver:
        return 'Bạc';
      case MemberTier.gold:
        return 'Vàng';
      case MemberTier.platinum:
        return 'Kim cương';
    }
  }
}

/// Hồ sơ khách hàng thành viên.
class Customer {
  final String id;
  final String name;
  final String phone;
  final String memberCode;
  final int points;
  final MemberTier tier;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.memberCode,
    required this.points,
    required this.tier,
  });
}
