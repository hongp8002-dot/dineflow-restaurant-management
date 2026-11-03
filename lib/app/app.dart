import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/session/session_store.dart';
import '../data/app_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/theme_settings.dart';
import 'app_navigator.dart';
import 'routes.dart';

/// Widget gốc của ứng dụng DineFlow.
///
/// Theo dõi chế độ giao diện ([AppThemeSettings.mode]) và độ sáng của hệ điều
/// hành để chọn bảng màu sáng/tối cho [AppColors].
class DineFlowApp extends StatefulWidget {
  /// Màn hình mở đầu: Đăng nhập, hoặc màn chính của vai trò nếu còn phiên đăng nhập.
  final String initialRoute;

  const DineFlowApp({super.key, this.initialRoute = AppRoutes.login});

  @override
  State<DineFlowApp> createState() => _DineFlowAppState();
}

class _DineFlowAppState extends State<DineFlowApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppThemeSettings.mode.addListener(_applyPalette);
    AppColors.usePalette(_resolvePalette());
  }

  @override
  void dispose() {
    AppThemeSettings.mode.removeListener(_applyPalette);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Hệ điều hành đổi sáng/tối: chỉ có tác dụng khi đang chọn "Theo hệ thống".
  @override
  void didChangePlatformBrightness() => _applyPalette();

  /// Mở lại app từ nền: tải mới trạng thái bàn (có thể đã đổi lúc app không hoạt động).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && SessionStore.instance.isSignedIn) {
      AppData.refresh(AppData.defaultSources());
    }
  }

  AppPalette _resolvePalette() {
    final dark = switch (AppThemeSettings.mode.value) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
    };
    return dark ? AppPalette.dark : AppPalette.light;
  }

  void _applyPalette() {
    final palette = _resolvePalette();
    if (identical(palette, AppColors.palette)) return;
    AppColors.usePalette(palette);
    setState(() {});

    // Các widget đọc màu trực tiếp từ AppColors trong build (kể cả widget
    // const), nên phải yêu cầu dựng lại toàn bộ cây. Chỉ dựng lại chứ không tạo
    // mới: tab đang mở, màn đang xem và nội dung đang nhập vẫn giữ nguyên.
    void markNeedsBuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(markNeedsBuild);
    }

    (context as Element).visitChildren(markNeedsBuild);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DineFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      // Đổi sáng/tối ngay lập tức để màu trong Theme khớp với màu đọc từ AppColors.
      themeAnimationDuration: Duration.zero,
      navigatorKey: AppNavigator.key,
      initialRoute: widget.initialRoute,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      // Icon thanh trạng thái tương phản với nền (màn không có AppBar).
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppColors.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: child!,
      ),
    );
  }
}
