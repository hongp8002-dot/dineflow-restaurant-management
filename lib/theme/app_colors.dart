import 'package:flutter/material.dart';

/// Bảng màu dùng chung cho toàn bộ ứng dụng DineFlow.
/// Tông chủ đạo: VÀNG (thương hiệu) - NÂU ĐEN ẤM (chữ/khối nhấn) - TRẮNG/KEM (nền),
/// lấy theo bộ mockup giao diện của nhóm (Trang chủ, Đăng nhập, Đặt bàn, Đơn gọi món).
///
/// Quy ước sử dụng:
/// - [primary] chỉ dùng làm NỀN (nút, chip đang chọn, badge, khối nhấn).
///   Chữ/icon nằm trên nền vàng phải dùng [textOnPrimary] (đen).
/// - Chữ/icon nhấn trên nền trắng dùng [textPrimary] (đen) — không dùng vàng
///   để tránh chữ vàng trên nền trắng bị chói và khó đọc.
/// - Chữ/icon nằm trên khối [ink] dùng [textOnDark].
/// Không hard-code màu trực tiếp trong widget, luôn tham chiếu tới đây.
///
/// Có hai bảng màu: [AppPalette.light] và [AppPalette.dark]. Mỗi màu ở đây đọc
/// từ bảng đang dùng nên **không còn là hằng số** (không đặt trong biểu thức
/// `const`). Đổi bảng màu bằng [AppThemeSettings] (lib/theme/theme_settings.dart).
class AppColors {
  AppColors._();

  static AppPalette _palette = AppPalette.light;

  /// Bảng màu đang dùng.
  static AppPalette get palette => _palette;

  static bool get isDark => _palette.brightness == Brightness.dark;

  /// Chỉ widget gốc của app gọi hàm này (kèm việc dựng lại toàn bộ giao diện).
  static void usePalette(AppPalette palette) => _palette = palette;

  // Thương hiệu: vàng chanh ấm.
  static Color get primary => _palette.primary;
  static Color get primaryDark => _palette.primaryDark;
  static Color get primaryLight => _palette.primaryLight;
  static Color get primarySoft => _palette.primarySoft;

  // Khối nhấn màu nâu đen ấm (chip đang chọn, thẻ thành viên...).
  // Mockup dùng nâu đen thay cho đen tuyền để hợp với tông vàng kem.
  static Color get ink => _palette.ink;
  static Color get inkSoft => _palette.inkSoft;

  /// Chữ nhấn màu vàng đặt trên khối [ink] (hạng thành viên, mã thẻ...).
  /// Chế độ tối khối [ink] là kem sáng nên dùng vàng nâu đậm thay cho vàng.
  static Color get primaryOnInk => _palette.primaryOnInk;

  /// Vàng nâu đậm: chỉ dùng cho chữ nhãn nhỏ in hoa (vd "LỊCH ĐẶT BÀN SẮP TỚI")
  /// và chữ "Flow" trong logo. Đủ tương phản trên nền trắng/vàng nhạt.
  static Color get accent => _palette.accent;

  // Nền & bề mặt. Mockup dùng nền trắng, các khối phụ (ô tìm kiếm, khối tổng
  // tiền, thẻ vai trò...) dùng màu kem nhạt.
  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceAlt => _palette.surfaceAlt;
  static Color get border => _palette.border;

  // Sọc chéo cho ô ảnh món (thay cho ảnh thật khi chưa có ảnh).
  static Color get stripeLight => _palette.stripeLight;
  static Color get stripeDark => _palette.stripeDark;

  // Văn bản.
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textOnPrimary => _palette.textOnPrimary;
  static Color get textOnDark => _palette.textOnDark;

  // Trạng thái.
  static Color get success => _palette.success;
  static Color get successBg => _palette.successBg;
  static Color get warning => _palette.warning;
  static Color get warningBg => _palette.warningBg;
  static Color get error => _palette.error;
  static Color get errorBg => _palette.errorBg;
  static Color get info => _palette.info;
  static Color get infoBg => _palette.infoBg;

  // Trạng thái bàn.
  static Color get tableEmpty => success;
  static Color get tableEmptyBg => successBg;
  static Color get tableServing => error;
  static Color get tableServingBg => errorBg;
  static Color get tableReserved => warning;
  static Color get tableReservedBg => warningBg;

  /// Nền vàng cho avatar, logo, dấu tích... Mockup dùng màu phẳng nên hai
  /// điểm màu giống nhau; giữ dạng gradient để có thể bật lại hiệu ứng chuyển
  /// màu ở một chỗ duy nhất nếu nhóm muốn.
  static LinearGradient get goldGradient => LinearGradient(colors: [primary, primary]);

  /// Nền nâu đen cho khối nhấn (thẻ thành viên) - cũng phẳng theo mockup.
  static LinearGradient get inkGradient => LinearGradient(colors: [ink, ink]);

  /// Bóng đổ của card. Mockup dùng phong cách phẳng (không đổ bóng, phân
  /// tách bằng viền mảnh hoặc nền kem) nên để trống; giữ getter để các nơi
  /// đang dùng không phải sửa, muốn bật lại bóng chỉ cần sửa ở đây.
  static List<BoxShadow> get softShadow => const [];

  /// Bóng của nút/khối vàng đang chọn - cũng để phẳng theo mockup.
  static List<BoxShadow> get goldShadow => const [];
}

/// Một bộ màu đầy đủ của app. Tên màu giữ nguyên nghĩa ở cả hai chế độ:
/// vd [ink] luôn là "khối nhấn tương phản với nền" (nâu đen ở chế độ sáng,
/// kem sáng ở chế độ tối) và [textOnDark] luôn là chữ nằm trên khối [ink].
class AppPalette {
  final Brightness brightness;

  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color primarySoft;
  final Color ink;
  final Color inkSoft;
  final Color primaryOnInk;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color stripeLight;
  final Color stripeDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;
  final Color textOnDark;
  final Color success;
  final Color successBg;
  final Color warning;
  final Color warningBg;
  final Color error;
  final Color errorBg;
  final Color info;
  final Color infoBg;

  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primarySoft,
    required this.ink,
    required this.inkSoft,
    required this.primaryOnInk,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.stripeLight,
    required this.stripeDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
    required this.textOnDark,
    required this.success,
    required this.successBg,
    required this.warning,
    required this.warningBg,
    required this.error,
    required this.errorBg,
    required this.info,
    required this.infoBg,
  });

  /// Bảng màu sáng - đúng theo mockup của nhóm.
  static const light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFFF7C948),
    primaryDark: Color(0xFFE3A812),
    primaryLight: Color(0xFFFFF4D4),
    primarySoft: Color(0xFFFDE9A9),
    ink: Color(0xFF3A2E25),
    inkSoft: Color(0xFF5A4C40),
    primaryOnInk: Color(0xFFF7C948),
    accent: Color(0xFFA0650A),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF8F4EC),
    border: Color(0xFFEDE5D8),
    stripeLight: Color(0xFFF9F4EA),
    stripeDark: Color(0xFFF1E7D3),
    textPrimary: Color(0xFF3A2E25),
    textSecondary: Color(0xFF85786A),
    textOnPrimary: Color(0xFF3A2E25),
    textOnDark: Color(0xFFFFFFFF),
    success: Color(0xFF1F9254),
    successBg: Color(0xFFE3F5EA),
    warning: Color(0xFFC98A04),
    warningBg: Color(0xFFFFF2D2),
    error: Color(0xFFD14343),
    errorBg: Color(0xFFFBE7E7),
    info: Color(0xFF3A6EA5),
    infoBg: Color(0xFFE6EEF7),
  );

  /// Bảng màu tối: nền nâu đen ấm thay cho trắng, khối kem thành nâu xám, vàng
  /// thương hiệu giữ nguyên (chữ trên nền vàng vẫn đen). Khối nhấn [ink] đảo
  /// thành kem sáng để vẫn nổi trên nền tối.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFFF7C948),
    primaryDark: Color(0xFFE3A812),
    primaryLight: Color(0xFF3A3020),
    primarySoft: Color(0xFF54451F),
    ink: Color(0xFFEFE6D8),
    inkSoft: Color(0xFFD5C9B8),
    primaryOnInk: Color(0xFF8A5A0B),
    accent: Color(0xFFE6AE52),
    background: Color(0xFF16120F),
    surface: Color(0xFF211B17),
    surfaceAlt: Color(0xFF2B241F),
    border: Color(0xFF3B332C),
    stripeLight: Color(0xFF29221D),
    stripeDark: Color(0xFF332A23),
    textPrimary: Color(0xFFF3ECE2),
    textSecondary: Color(0xFFAA9D8E),
    textOnPrimary: Color(0xFF3A2E25),
    textOnDark: Color(0xFF2A211A),
    success: Color(0xFF4CC38A),
    successBg: Color(0xFF173226),
    warning: Color(0xFFE5B23A),
    warningBg: Color(0xFF3A2E12),
    error: Color(0xFFF07575),
    errorBg: Color(0xFF3D2020),
    info: Color(0xFF86AEDB),
    infoBg: Color(0xFF1C2A3A),
  );
}
