import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_animations.dart';

/// Hàng 2 nút "Google" và "Facebook" dùng ở màn Đăng nhập.
///
/// CHỈ là giao diện: chưa tích hợp Google Sign-In / Facebook Login. Màn hình
/// cha truyền [onGoogle] / [onFacebook] để xử lý (hiện tại chỉ báo demo).
///
/// Logo được vẽ bằng [CustomPainter] theo đúng hình dạng và mã màu chính thức
/// của hai hãng, nên không cần thêm thư viện (flutter_svg) hay file ảnh, và
/// vẫn sắc nét ở mọi kích thước.
class SocialLoginButtons extends StatelessWidget {
  final VoidCallback onGoogle;
  final VoidCallback onFacebook;

  const SocialLoginButtons({super.key, required this.onGoogle, required this.onFacebook});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SocialLoginButton(
            logo: const GoogleLogo(),
            label: 'Google',
            onTap: onGoogle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SocialLoginButton(
            logo: const FacebookLogo(),
            label: 'Facebook',
            onTap: onFacebook,
          ),
        ),
      ],
    );
  }
}

/// Một nút đăng nhập mạng xã hội: nền trắng, viền mảnh, logo + nhãn ở giữa.
class SocialLoginButton extends StatelessWidget {
  final Widget logo;
  final String label;
  final VoidCallback onTap;

  const SocialLoginButton({super.key, required this.logo, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Đăng nhập bằng $label',
      child: PressScale(
        onTap: onTap,
        scale: 0.96,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 22, height: 22, child: logo),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Logo Google ─────────────────────────────────────────────────────────────

/// Chữ "G" 4 màu của Google, vẽ theo đường path của logo chính thức
/// (hệ toạ độ gốc 48x48, được co giãn theo kích thước widget).
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GoogleLogoPainter());
}

class _GoogleLogoPainter extends CustomPainter {
  // Mã màu chính thức của Google.
  static const _red = Color(0xFFEA4335);
  static const _blue = Color(0xFF4285F4);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 48;
    canvas.save();
    canvas.scale(s, s);
    final paint = Paint()..isAntiAlias = true;

    // Đỏ – cung trên.
    final red = Path()
      ..moveTo(24, 9.5)
      ..cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1)
      ..lineTo(40.06, 6.25)
      ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
      ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
      ..lineTo(10.54, 19.41)
      ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
      ..close();
    canvas.drawPath(red, paint..color = _red);

    // Xanh dương – cung phải + thanh ngang.
    final blue = Path()
      ..moveTo(46.98, 24.55)
      ..cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20)
      ..lineTo(24, 20)
      ..lineTo(24, 29.02)
      ..lineTo(36.94, 29.02)
      ..cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2)
      ..lineTo(39.89, 42.2)
      ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
      ..close();
    canvas.drawPath(blue, paint..color = _blue);

    // Vàng – cung trái.
    final yellow = Path()
      ..moveTo(10.53, 28.59)
      ..cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24)
      ..cubicTo(9.77, 22.4, 10.04, 20.86, 10.53, 19.41)
      ..lineTo(2.55, 13.22)
      ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
      ..cubicTo(0, 27.88, 0.92, 31.54, 2.56, 34.78)
      ..close();
    canvas.drawPath(yellow, paint..color = _yellow);

    // Xanh lá – cung dưới.
    final green = Path()
      ..moveTo(24, 48)
      ..cubicTo(30.48, 48, 35.93, 45.87, 39.89, 42.19)
      ..lineTo(32.16, 36.19)
      ..cubicTo(30.01, 37.64, 27.24, 38.49, 24, 38.49)
      ..cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58)
      ..lineTo(2.55, 34.77)
      ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
      ..close();
    canvas.drawPath(green, paint..color = _green);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Logo Facebook ───────────────────────────────────────────────────────────

/// Logo Facebook hiện hành: hình tròn xanh (#0866FF) với chữ "f" trắng, thân
/// chữ chạm mép dưới hình tròn. Vẽ theo hệ toạ độ gốc 24x24.
class FacebookLogo extends StatelessWidget {
  final double size;
  const FacebookLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _FacebookLogoPainter());
}

class _FacebookLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF0866FF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    canvas.save();
    canvas.scale(s, s);
    final paint = Paint()..isAntiAlias = true;

    final circle = Path()..addOval(const Rect.fromLTWH(0, 0, 24, 24));
    canvas.drawPath(circle, paint..color = _blue);

    // Cắt theo hình tròn để thân chữ "f" kết thúc đúng ở mép dưới.
    canvas.clipPath(circle);

    final f = Path()
      ..moveTo(9.1, 24.5)
      ..lineTo(9.1, 15.71)
      ..lineTo(6.63, 15.71)
      ..lineTo(6.63, 12.04)
      ..lineTo(9.1, 12.04)
      ..lineTo(9.1, 10.46)
      ..cubicTo(9.1, 6.38, 10.95, 4.49, 14.96, 4.49)
      ..cubicTo(15.36, 4.49, 15.91, 4.53, 16.43, 4.59)
      ..quadraticBezierTo(17.0, 4.65, 17.57, 4.78)
      ..lineTo(17.57, 8.11)
      ..quadraticBezierTo(17.24, 8.08, 16.92, 8.07)
      ..lineTo(16.18, 8.06)
      ..cubicTo(15.48, 8.06, 14.92, 8.16, 14.51, 8.37)
      ..quadraticBezierTo(14.06, 8.6, 13.83, 9.0)
      ..cubicTo(13.57, 9.42, 13.45, 9.99, 13.45, 10.75)
      ..lineTo(13.45, 12.04)
      ..lineTo(17.37, 12.04)
      ..lineTo(16.7, 15.71)
      ..lineTo(13.45, 15.71)
      ..lineTo(13.45, 24.5)
      ..close();
    canvas.drawPath(f, paint..color = Colors.white);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
