import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dineflow/screens/admin/account_management_screen.dart';
import 'package:dineflow/screens/admin/admin_dashboard_screen.dart';
import 'package:dineflow/screens/admin/admin_shell.dart';
import 'package:dineflow/screens/admin/menu_management_screen.dart';
import 'package:dineflow/screens/admin/promotion_management_screen.dart';
import 'package:dineflow/screens/admin/revenue_report_screen.dart';
import 'package:dineflow/screens/admin/table_area_management_screen.dart';
import 'package:dineflow/theme/app_theme.dart';

/// Smoke test giao diện cho nhóm màn hình Admin: dựng từng màn trên các cỡ máy
/// phổ biến và bắt lỗi tràn layout (RenderFlex overflowed).
void main() {
  // 320x640 là máy nhỏ, dễ lộ lỗi nhất; 640x900 là ngưỡng AdminShell chuyển
  // từ BottomNavigationBar sang NavigationRail nên cần kiểm tra riêng.
  const sizes = <String, Size>{
    'may pho thong 360x800': Size(360, 800),
    'may nho 320x640': Size(320, 640),
    'tablet 800x1000': Size(800, 1000),
  };

  final screens = <String, Widget Function()>{
    'AdminShell': () => const AdminShell(),
    'AdminDashboardScreen': () => const AdminDashboardScreen(),
    'AccountManagementScreen': () => const AccountManagementScreen(),
    'MenuManagementScreen': () => const MenuManagementScreen(),
    'TableAreaManagementScreen': () => const TableAreaManagementScreen(),
    'PromotionManagementScreen': () => const PromotionManagementScreen(),
    'RevenueReportScreen': () => const RevenueReportScreen(),
  };

  sizes.forEach((sizeName, size) {
    group('Kích thước $sizeName', () {
      screens.forEach((screenName, builder) {
        testWidgets('$screenName dựng được, không tràn layout', (tester) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: builder()));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });
      });
    });
  });
  group('Chức năng Admin', () {
    testWidgets('Dashboard có nút Đăng xuất (bản điện thoại không có thanh rail)', (tester) async {
      tester.view.physicalSize = const Size(360, 800) * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: const AdminShell()));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Đăng xuất'), findsOneWidget);
    });

    testWidgets('Khoá tài khoản cập nhật ngay nhãn trạng thái trên giao diện', (tester) async {
      tester.view.physicalSize = const Size(360, 800) * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.current, home: const AccountManagementScreen()),
      );
      await tester.pumpAndSettle();

      // Màn hình này chỉ demo giao diện: trạng thái đổi trong state cục bộ,
      // việc lưu thật sự thuộc về backend nên không kiểm tra dữ liệu dùng chung.
      final lockedBefore = find.text('Đã khóa').evaluate().length;

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khóa').last);
      await tester.pumpAndSettle();

      expect(find.text('Đã khóa'), findsNWidgets(lockedBefore + 1));
      expect(find.textContaining('Đã khóa tài khoản'), findsOneWidget);
    });
  });
}
