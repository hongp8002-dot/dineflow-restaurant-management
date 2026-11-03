import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/session/session_store.dart';
import '../../data/loyalty_rules.dart';
import '../../models/customer.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';

/// Màn hình QR thành viên: thông tin thành viên, điểm thưởng và mã QR thật
/// (chứa mã thẻ, vd "DF-000123") để thu ngân quét khi thanh toán.
class MemberQrScreen extends StatelessWidget {
  const MemberQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SessionStore.instance.user;

    // Nếu chưa đăng nhập (không bao giờ xảy ra khi đã vào app) → màn loading
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Derive tier từ điểm thưởng vì User không lưu tier trực tiếp.
    final tier = LoyaltyRules.tierFor(user.points);
    final memberCode = user.memberCode ?? 'DF-000000';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const AppPageHeader(title: 'Thẻ thành viên', subtitle: 'Tích điểm và dùng ưu đãi khi thanh toán'),
            const SizedBox(height: 18),
            _MemberCard(name: user.name, memberCode: memberCode, tier: tier),
            const SizedBox(height: 20),
            FadeSlideIn(
              delay: const Duration(milliseconds: 220),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: Icon(Icons.stars_rounded, color: AppColors.textOnPrimary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Điểm tích luỹ',
                                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              CountUpText(
                                value: user.points.toDouble(),
                                formatter: (v) => '${v.round()} điểm',
                                style: TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        _TierBenefitChip(tier: tier),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _TierProgress(points: user.points, tier: tier),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 320),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primarySoft),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Đưa mã QR này cho thu ngân khi thanh toán để được giảm giá theo hạng '
                        'và tích ${LoyaltyRules.pointsPerStep} điểm cho mỗi '
                        '${AppFormatters.currency(LoyaltyRules.amountPerStep)}.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ thành viên màu đen viền vàng, xuất hiện kèm hiệu ứng lật nhẹ.
class _MemberCard extends StatefulWidget {
  final String name;
  final String memberCode;
  final MemberTier tier;

  const _MemberCard({required this.name, required this.memberCode, required this.tier});

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final angle = (1 - curved.value) * -0.6;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: Opacity(opacity: curved.value.clamp(0, 1), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: AppColors.inkGradient,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.primary, width: 1.4),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.person_rounded, color: AppColors.textOnPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textOnDark, fontWeight: FontWeight.w800, fontSize: 16.5)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Hạng ${widget.tier.label}',
                            style: TextStyle(
                                color: AppColors.textOnPrimary, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            // Mã QR luôn in đậm trên nền trắng (cả ở chế độ tối) để máy quét đọc được.
            Container(
              padding: const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(color: AppPalette.light.surface, borderRadius: BorderRadius.circular(20)),
              child: QrImageView(
                data: widget.memberCode,
                version: QrVersions.auto,
                size: 180,
                padding: EdgeInsets.zero,
                backgroundColor: AppPalette.light.surface,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: AppPalette.light.ink),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppPalette.light.ink,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.memberCode,
              style: TextStyle(
                color: AppColors.primaryOnInk,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn quyền lợi của hạng hiện tại, vd "Giảm 5%".
class _TierBenefitChip extends StatelessWidget {
  final MemberTier tier;
  const _TierBenefitChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    final percent = tier.discountPercent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: percent > 0 ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        percent > 0 ? 'Giảm $percent%' : 'Chưa có ưu đãi',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: percent > 0 ? AppColors.primaryOnInk : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Thanh tiến độ lên hạng kế tiếp.
class _TierProgress extends StatelessWidget {
  final int points;
  final MemberTier tier;
  const _TierProgress({required this.points, required this.tier});

  @override
  Widget build(BuildContext context) {
    final next = tier.next;
    if (next == null) {
      return Text(
        'Bạn đang ở hạng cao nhất · Giảm ${tier.discountPercent}% mỗi hoá đơn',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      );
    }

    final from = tier.minPoints;
    final to = next.minPoints;
    final progress = ((points - from) / (to - from)).clamp(0.0, 1.0);
    final remaining = (to - points).clamp(0, to);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: AppMotion.slow,
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Còn $remaining điểm để lên hạng ${next.label} (giảm ${next.discountPercent}%)',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
