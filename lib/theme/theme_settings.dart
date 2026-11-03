import 'package:flutter/material.dart';

/// Chế độ giao diện người dùng chọn ở trang tài khoản: Sáng / Tối / Theo hệ thống.
///
/// Widget gốc (`DineFlowApp`) lắng nghe [mode] và đổi bảng màu [AppColors]
/// tương ứng. Ở giai đoạn mock, lựa chọn chỉ lưu trong RAM như các dữ liệu
/// khác: tắt app mở lại sẽ về mặc định (Sáng, đúng theo mockup).
class AppThemeSettings {
  AppThemeSettings._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  /// Thứ tự hiển thị trong bảng chọn.
  static const options = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  static String label(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Sáng',
        ThemeMode.dark => 'Tối',
        ThemeMode.system => 'Theo hệ thống',
      };

  static IconData icon(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
        ThemeMode.system => Icons.brightness_auto_outlined,
      };
}
