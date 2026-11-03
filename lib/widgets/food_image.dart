import 'package:flutter/material.dart';

import '../models/food.dart';
import '../theme/app_colors.dart';

/// Ô ảnh món ăn theo mockup: nền sọc chéo màu kem, góc bo tròn.
///
/// Món có [Food.image] thì hiện ảnh thật; món chưa có ảnh (hoặc ảnh lỗi) thì
/// hiện ô sọc chéo với icon của món ở giữa để người dùng vẫn nhận ra món.
class FoodImage extends StatelessWidget {
  final Food food;
  final double borderRadius;
  final double iconSize;

  const FoodImage({
    super.key,
    required this.food,
    this.borderRadius = 20,
    this.iconSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = CustomPaint(
      painter: _StripePainter(light: AppColors.stripeLight, dark: AppColors.stripeDark),
      child: Center(
        child: Icon(food.icon, size: iconSize, color: food.color.withValues(alpha: 0.85)),
      ),
    );
    final image = food.image;
    Widget errorBuilder(BuildContext _, Object __, StackTrace? ___) => placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: switch (image) {
        null => placeholder,
        // Chạy trên web (Chrome): ảnh ở server khác địa chỉ mà không có header CORS thì trình duyệt
        // chặn tải theo cách thường. `fallback` cho phép Flutter hiện bằng thẻ <img> của trình duyệt
        // (không cần CORS). Trên Android/iOS tham số này không có tác dụng.
        final url when url.startsWith('http') => Image.network(url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: errorBuilder,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback),
        final path => Image.asset(path,
            fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: errorBuilder),
      },
    );
  }
}

/// Vẽ các sọc chéo 45 độ xen kẽ hai tông kem.
class _StripePainter extends CustomPainter {
  final Color light;
  final Color dark;

  const _StripePainter({required this.light, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);

    const stripeWidth = 14.0;
    final paint = Paint()
      ..color = dark
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    // Vẽ đường chéo từ trái-dưới lên phải-trên, phủ kín cả hình chữ nhật.
    final span = size.width + size.height;
    for (double x = -size.height; x < span; x += stripeWidth * 2) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) =>
      oldDelegate.light != light || oldDelegate.dark != dark;
}
