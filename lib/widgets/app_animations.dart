import 'package:flutter/material.dart';

/// Bộ hiệu ứng chuyển động dùng chung cho toàn app.
/// Mục tiêu: các màn hình có cảm giác "mobile" - nội dung xuất hiện mềm mại,
/// nút bấm có phản hồi, số liệu thay đổi có chuyển tiếp.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;

  /// Độ trễ tăng dần theo thứ tự phần tử (hiệu ứng "đổ" lần lượt).
  static Duration stagger(int index, {int stepMs = 55, int maxMs = 420}) {
    final ms = index * stepMs;
    return Duration(milliseconds: ms > maxMs ? maxMs : ms);
  }
}

/// Hiện dần + trượt lên khi widget được dựng lần đầu.
/// Dùng cho item danh sách, section trang chủ, card...
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Khoảng trượt theo trục dọc (px). Số âm sẽ trượt từ trên xuống.
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.normal,
    this.offsetY = 18,
  });

  /// Tiện ích cho danh sách: tự tính độ trễ theo chỉ số phần tử.
  factory FadeSlideIn.staggered({
    Key? key,
    required int index,
    required Widget child,
    double offsetY = 18,
  }) {
    return FadeSlideIn(
      key: key,
      delay: AppMotion.stagger(index),
      offsetY: offsetY,
      child: child,
    );
  }

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  // Độ trễ được gộp vào chính AnimationController (qua Interval) thay vì dùng
  // Future.delayed: không tạo Timer riêng, nên khi widget bị huỷ sớm (chuyển
  // màn nhanh, hoặc widget test kết thúc) sẽ không còn Timer treo lại.
  late final Duration _total = widget.delay + widget.duration;
  late final AnimationController _controller = AnimationController(vsync: this, duration: _total);
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _total.inMicroseconds == 0 ? 0 : widget.delay.inMicroseconds / _total.inMicroseconds,
      1,
      curve: AppMotion.enter,
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - _animation.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Bọc một widget để khi nhấn giữ sẽ thu nhỏ lại (phản hồi chạm).
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final BorderRadius? borderRadius;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.borderRadius,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Text có hiệu ứng chuyển tiếp mỗi khi giá trị thay đổi (giá tiền, số lượng...).
class AnimatedValueText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;

  const AnimatedValueText(this.value, {super.key, this.style, this.textAlign});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        value,
        key: ValueKey(value),
        style: style,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Đếm số tăng dần từ 0 tới [value] (dùng cho điểm thưởng, thống kê).
class CountUpText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String Function(num value)? formatter;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.formatter,
    this.duration = AppMotion.slow,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        formatter?.call(v) ?? v.round().toString(),
        style: style,
      ),
    );
  }
}
