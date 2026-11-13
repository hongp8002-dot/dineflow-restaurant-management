import '../models/customer.dart';

/// Quy tắc thành viên của DineFlow (nhóm đã chốt "Kiểu A – giảm theo hạng").
///
/// - Điểm chỉ dùng để **xét hạng**, không bao giờ bị trừ hay đổi thành tiền.
/// - Mỗi hạng được **giảm % mặc định** trên hoá đơn.
/// - Giảm theo hạng **không cộng dồn** với voucher: lấy mức giảm cao hơn.
///
/// **Nguồn chính là server** (`config/loyalty.php`): sau khi đăng nhập, app tải quy tắc qua
/// `GET /api/settings` rồi gọi [apply]. Các giá trị khai báo dưới đây chỉ là giá trị ban đầu
/// trước khi tải xong (hoặc khi đang chạy test không có server), trùng với cấu hình server.
/// App chỉ dùng quy tắc để HIỂN THỊ; số tiền giảm và điểm cộng thật luôn do server tính.
class LoyaltyRules {
  LoyaltyRules._();

  /// Cứ mỗi [amountPerStep] đồng khách **thực trả** thì được [pointsPerStep] điểm.
  static int amountPerStep = 10000;
  static int pointsPerStep = 2;

  static final Map<MemberTier, int> _minPoints = {
    MemberTier.silver: 0,
    MemberTier.gold: 500,
    MemberTier.platinum: 1500,
  };

  static final Map<MemberTier, int> _discountPercent = {
    MemberTier.silver: 0,
    MemberTier.gold: 5,
    MemberTier.platinum: 10,
  };

  /// Nhận quy tắc từ server (phần `loyalty` của `GET /api/settings`).
  /// Thiếu trường nào thì giữ giá trị đang có của trường đó.
  static void apply(Map<String, dynamic> json) {
    amountPerStep = (json['amount_per_step'] as num?)?.toInt() ?? amountPerStep;
    pointsPerStep = (json['points_per_step'] as num?)?.toInt() ?? pointsPerStep;

    final tiers = json['tiers'];
    if (tiers is Map<String, dynamic>) {
      for (final tier in MemberTier.values) {
        final rule = tiers[tier.name];
        if (rule is! Map<String, dynamic>) continue;
        _minPoints[tier] = (rule['min_points'] as num?)?.toInt() ?? _minPoints[tier]!;
        _discountPercent[tier] = (rule['discount_percent'] as num?)?.toInt() ?? _discountPercent[tier]!;
      }
    }
  }

  /// Điểm được cộng cho số tiền thực trả (sau giảm giá), làm tròn xuống theo
  /// từng mức. Vd 95.000đ → 9 mức → 18 điểm.
  static int pointsEarned(num paidAmount) {
    if (paidAmount <= 0) return 0;
    return (paidAmount ~/ amountPerStep) * pointsPerStep;
  }

  /// Hạng tương ứng với tổng điểm tích luỹ.
  static MemberTier tierFor(int points) {
    if (points >= MemberTier.platinum.minPoints) return MemberTier.platinum;
    if (points >= MemberTier.gold.minPoints) return MemberTier.gold;
    return MemberTier.silver;
  }
}

/// Thông số của từng hạng thành viên (lấy theo quy tắc đang áp dụng ở [LoyaltyRules]).
extension MemberTierRules on MemberTier {
  /// Điểm tích luỹ tối thiểu để đạt hạng.
  int get minPoints => LoyaltyRules._minPoints[this]!;

  /// % giảm mặc định trên hoá đơn của hạng.
  int get discountPercent => LoyaltyRules._discountPercent[this]!;

  /// Hạng kế tiếp; null nếu đã là hạng cao nhất.
  MemberTier? get next => switch (this) {
        MemberTier.silver => MemberTier.gold,
        MemberTier.gold => MemberTier.platinum,
        MemberTier.platinum => null,
      };
}
