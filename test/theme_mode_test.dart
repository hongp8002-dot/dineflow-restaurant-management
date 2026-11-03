import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dineflow/app/app.dart';
import 'package:dineflow/theme/app_colors.dart';
import 'package:dineflow/theme/theme_settings.dart';
import 'package:dineflow/widgets/app_bottom_nav.dart';

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Màu nền của thanh điều hướng dưới - một widget dựng sẵn từ trước khi đổi giao diện.
Color? _bottomNavColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(AppBottomNav), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  tearDown(() {
    AppThemeSettings.mode.value = ThemeMode.light;
    AppColors.usePalette(AppPalette.light);
  });

  testWidgets('Đổi giao diện Sáng/Tối ở tab Tài khoản: cả app đổi màu, vẫn ở nguyên màn đang xem',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DineFlowApp());
    await tester.pumpAndSettle();
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(0), '0901234567');
    await tester.enterText(textFields.at(1), '1234');
    await _tapVisible(tester, find.text('Đăng nhập'));

    // Mặc định là giao diện Sáng (đúng theo mockup).
    await _tapVisible(tester, find.text('Tài khoản'));
    expect(AppColors.isDark, isFalse);
    expect(_bottomNavColor(tester), AppPalette.light.surface);

    // ----- Chọn "Tối" -----
    await _tapVisible(tester, find.byKey(const ValueKey('theme-mode-tile')));
    expect(find.text('Theo hệ thống'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey('theme-option-dark')));

    expect(AppColors.isDark, isTrue);
    expect(Theme.of(tester.element(find.byType(AppBottomNav))).brightness, Brightness.dark);
    // Widget dựng sẵn cũng đổi màu (cả cây được dựng lại), mà vẫn ở tab Tài khoản.
    expect(_bottomNavColor(tester), AppPalette.dark.surface);
    // (Thẻ "Hạng thành viên" ở đầu trang có thể đã cuộn khỏi màn hình nên kiểm tra mục cạnh nút giao diện.)
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('theme-mode-tile')), matching: find.text('Tối')),
        findsOneWidget);

    // ----- Về lại "Sáng" -----
    await _tapVisible(tester, find.byKey(const ValueKey('theme-mode-tile')));
    await _tapVisible(tester, find.byKey(const ValueKey('theme-option-light')));
    expect(AppColors.isDark, isFalse);
    expect(_bottomNavColor(tester), AppPalette.light.surface);
  });

  testWidgets('"Theo hệ thống" đi theo chế độ sáng/tối của điện thoại', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    await tester.pumpWidget(const DineFlowApp());
    await tester.pumpAndSettle();
    expect(AppColors.isDark, isFalse);

    AppThemeSettings.mode.value = ThemeMode.system;
    await tester.pumpAndSettle();
    expect(AppColors.isDark, isTrue);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(AppColors.isDark, isFalse);
  });
}
