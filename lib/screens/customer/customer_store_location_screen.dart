import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';

class CustomerStoreLocationScreen extends StatelessWidget {
  const CustomerStoreLocationScreen({super.key});

  static const _name = 'DineFlow Restaurant';
  static const _address = '140 Lê Trọng Tấn, Phường Tây Thạnh, Tân Phú, TP. Hồ Chí Minh';
  static const _phone = '1800 1234';
  // Dùng chuỗi địa chỉ để Google Maps tự geocode – chính xác hơn tọa độ
  static const _addressQuery =
      '140 Lê Trọng Tấn, Phường Tây Thạnh, Quận Tân Phú, TP. Hồ Chí Minh';

  static const _hours = [
    ('Thứ 2 – Thứ 6', '10:00 – 22:00'),
    ('Thứ 7 – Chủ nhật', '09:00 – 23:00'),
  ];

  Future<void> _openMaps(BuildContext context) async {
    // geo: URI với chuỗi địa chỉ → mở Google Maps app tìm đúng địa điểm
    final encoded = Uri.encodeComponent(_addressQuery);
    final geoUri = Uri.parse('geo:0,0?q=$encoded');
    // Fallback: Google Maps web với địa chỉ
    final webUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encoded');

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Không thể mở Google Maps'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _callPhone(BuildContext context) async {
    final uri = Uri.parse('tel:${_phone.replaceAll(' ', '')}');
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    var idx = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: idx++, child: child);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            step(const AppPageHeader(title: 'Vị trí cửa hàng')),
            const SizedBox(height: 18),

            // ── Map placeholder (vẽ bằng Flutter, không cần internet) ────────
            step(GestureDetector(
              onTap: () => _openMaps(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Nền gradient màu bản đồ
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1b2f4b), Color(0xFF243d5c)],
                          ),
                        ),
                      ),
                      // Lưới đường giả lập bản đồ
                      CustomPaint(painter: _MapGridPainter()),
                      // Pin + tên quán
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_pin,
                            color: Color(0xFFe84545),
                            size: 44,
                            shadows: [
                              Shadow(
                                color: Colors.black38,
                                offset: Offset(0, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              _name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1b2f4b),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Badge "Mở Google Maps"
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new_rounded,
                                  size: 13, color: AppColors.primaryOnInk),
                              const SizedBox(width: 5),
                              Text(
                                'Mở Google Maps',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryOnInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),

            const SizedBox(height: 16),

            // ── Thông tin cửa hàng ────────────────────────────────────────
            step(Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Địa chỉ',
                    value: _address,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Điện thoại',
                    value: _phone,
                    onTap: () => _callPhone(context),
                    tapLabel: 'Gọi ngay',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Giờ mở cửa',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final (day, time) in _hours)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(day,
                                          style: TextStyle(
                                              fontSize: 13.5,
                                              color: AppColors.textPrimary)),
                                    ),
                                    Text(time,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        )),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )),

            const SizedBox(height: 16),

            // ── Nút chỉ đường ────────────────────────────────────────────
            step(PressScale(
              onTap: () => _openMaps(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_rounded,
                        size: 20, color: AppColors.primaryOnInk),
                    const SizedBox(width: 8),
                    Text(
                      'Chỉ đường đến quán',
                      style: TextStyle(
                        color: AppColors.primaryOnInk,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Map grid painter ──────────────────────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF2e5080).withValues(alpha: 0.5)
      ..strokeWidth = 1;

    const stepY = 30.0;
    for (double y = 0; y < size.height; y += stepY) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    const stepX = 50.0;
    for (double x = 0; x < size.width; x += stepX) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    final boldPaint = Paint()
      ..color = const Color(0xFF3a6fa0).withValues(alpha: 0.6)
      ..strokeWidth = 2.5;

    canvas.drawLine(Offset(0, size.height * 0.4),
        Offset(size.width, size.height * 0.4), boldPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0),
        Offset(size.width * 0.35, size.height), boldPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0),
        Offset(size.width * 0.7, size.height), boldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? tapLabel;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.tapLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4)),
            ],
          ),
        ),
        if (onTap != null && tapLabel != null)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(tapLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  )),
            ),
          ),
      ],
    );
  }
}
