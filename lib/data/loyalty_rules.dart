import '../models/customer.dart';

/// Quy tắc thành viên của DineFlow (nhóm đã chốt "Kiểu A – giảm theo hạng").
///
/// - Điểm chỉ dùng để **xét hạng**, không bao giờ bị trừ hay đổi thành tiền.
/// - Mỗi hạng được **giảm % mặc định** trên hoá đơn.
/// - Giảm theo hạng **không cộng dồn** với voucher: lấy mức giảm cao hơn.
///
/// Mọi con số đều nằm ở file này; muốn đổi quy tắc chỉ cần sửa tại đây.
/// Khi có backend, server sẽ tính theo cùng quy tắc (app chỉ để hiển thị).
class LoyaltyRules {
  LoyaltyRules._();

  /// Cứ mỗi [amountPerStep] đồng khách **thực trả** thì được [pointsPerStep] điểm.
  static const int amountPerStep = 10000;
  static const int pointsPerStep = 2;

  /// Điểm được cộng cho số tiền thực trả (sau giảm giá), làm tròn xuống theo
  /// từng mức 10.000đ. Vd 95.000đ → 9 mức → 18 điểm.
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

/// Thông số của từng hạng thành viên.
extension MemberTierRules on MemberTier {
  /// Điểm tích luỹ tối thiểu để đạt hạng.
  int get minPoints => switch (this) {
        MemberTier.silver => 0,
        MemberTier.gold => 500,
        MemberTier.platinum => 1500,
      };

  /// % giảm mặc định trên hoá đơn của hạng.
  int get discountPercent => switch (this) {
        MemberTier.silver => 0,
        MemberTier.gold => 5,
        MemberTier.platinum => 10,
      };

  /// Hạng kế tiếp; null nếu đã là hạng cao nhất.
  MemberTier? get next => switch (this) {
        MemberTier.silver => MemberTier.gold,
        MemberTier.gold => MemberTier.platinum,
        MemberTier.platinum => null,
      };
}
