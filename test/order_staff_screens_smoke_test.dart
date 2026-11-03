import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dineflow/data/cart_store.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/models/table_model.dart';
import 'package:dineflow/screens/order_staff/create_order_screen.dart';
import 'package:dineflow/screens/order_staff/merge_table_screen.dart';
import 'package:dineflow/screens/order_staff/order_entry_screen.dart';
import 'package:dineflow/screens/order_staff/order_staff_shell.dart';
import 'package:dineflow/screens/order_staff/serving_orders_screen.dart';
import 'package:dineflow/screens/order_staff/staff_profile_screen.dart';
import 'package:dineflow/screens/order_staff/table_detail_screen.dart';
import 'package:dineflow/screens/order_staff/table_management_screen.dart';
import 'package:dineflow/screens/order_staff/transfer_table_screen.dart';
import 'package:dineflow/theme/app_theme.dart';
import 'package:dineflow/widgets/app_bottom_nav.dart';

void _usePhone(WidgetTester tester, [Size size = const Size(360, 800)]) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: home));
  await tester.pumpAndSettle();
}

/// Smoke test giao diện cho nhóm màn hình Nhân viên Order.
void main() {
  const sizes = <String, Size>{
    'may pho thong 360x800': Size(360, 800),
    'may nho 320x640': Size(320, 640),
  };

  // Bàn trống (chưa có đơn) và bàn đang phục vụ (có đơn) hiển thị khác nhau.
  final emptyTable = MockData.tables.firstWhere((t) => t.status == TableStatus.empty);
  final servingTable = MockData.tables.firstWhere((t) => t.status == TableStatus.serving);

  final screens = <String, Widget Function()>{
    'OrderStaffShell': () => const OrderStaffShell(),
    'TableManagementScreen': () => const TableManagementScreen(),
    'OrderEntryScreen': () => const OrderEntryScreen(),
    'ServingOrdersScreen': () => const ServingOrdersScreen(),
    'StaffProfileScreen': () => const StaffProfileScreen(),
    'CreateOrderScreen (bàn trống)': () => CreateOrderScreen(tableId: emptyTable.id),
    'CreateOrderScreen (thêm vào đơn)': () => CreateOrderScreen(tableId: servingTable.id),
    'TableDetailScreen (bàn trống)': () => TableDetailScreen(tableId: emptyTable.id),
    'TableDetailScreen (đang phục vụ)': () => TableDetailScreen(tableId: servingTable.id),
    'TransferTableScreen': () => TransferTableScreen(currentTableId: servingTable.id),
    'MergeTableScreen': () => MergeTableScreen(initialTableId: servingTable.id),
  };

  sizes.forEach((sizeName, size) {
    group('Kích thước $sizeName', () {
      screens.forEach((screenName, builder) {
        testWidgets('$screenName dựng được, không tràn layout', (tester) async {
          _usePhone(tester, size);
          await _pump(tester, builder());
          expect(tester.takeException(), isNull);
        });
      });
    });
  });

  group('Chức năng màn Order món', () {
    final firstFood = MockData.foods.firstWhere((f) => f.isAvailable);

    testWidgets('Bấm + thì món hiện bộ tăng giảm và thanh dưới cập nhật tổng', (tester) async {
      addTearDown(AppCart.staffOrder.clear);
      _usePhone(tester);
      await _pump(tester, CreateOrderScreen(tableId: servingTable.id));

      expect(find.text('Chưa chọn món'), findsOneWidget);
      expect(find.textContaining('thêm vào đơn #'), findsOneWidget);
      expect(find.byKey(const ValueKey('stepper')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('add')).first);
      await tester.pumpAndSettle();

      expect(find.text('Tổng tiền · 1 món'), findsOneWidget);
      expect(find.byKey(const ValueKey('stepper')), findsOneWidget);
      expect(find.text('Thêm ghi chú'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bấm quay lại khi order đang có món thì phải hỏi lại', (tester) async {
      addTearDown(AppCart.staffOrder.clear);
      _usePhone(tester);
      await _pump(tester, CreateOrderScreen(tableId: emptyTable.id));

      await tester.tap(find.text(firstFood.name).first);
      await tester.pumpAndSettle();

      // Giả lập nút Back của hệ điều hành.
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Huỷ order đang tạo?'), findsOneWidget);
    });

    testWidgets('Chạm nhiều lần vào một món thì tăng số lượng, không thêm dòng mới', (tester) async {
      addTearDown(AppCart.staffOrder.clear);
      _usePhone(tester);
      await _pump(tester, CreateOrderScreen(tableId: emptyTable.id));

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text(firstFood.name).first);
        await tester.pumpAndSettle();
      }

      // Một dòng duy nhất trong order với số lượng 3.
      expect(AppCart.staffOrder.items.length, 1);
      expect(AppCart.staffOrder.items.first.quantity, 3);
      expect(find.text('Tổng tiền · 3 món'), findsOneWidget);
    });

    testWidgets('Giảm số lượng về 0 thì món rời khỏi order', (tester) async {
      addTearDown(AppCart.staffOrder.clear);
      _usePhone(tester);
      await _pump(tester, CreateOrderScreen(tableId: emptyTable.id));

      await tester.tap(find.byKey(const ValueKey('add')).first);
      await tester.pumpAndSettle();
      final stepper = find.byKey(const ValueKey('stepper'));
      await tester.tap(find.descendant(of: stepper, matching: find.byIcon(Icons.remove_rounded)));
      await tester.pumpAndSettle();

      expect(AppCart.staffOrder.isEmpty, isTrue);
      expect(find.text('Chưa chọn món'), findsOneWidget);
      expect(stepper, findsNothing);
    });
  });

  group('Chuyển bàn, gộp bàn, cá nhân', () {
    testWidgets('Chọn bàn trống thì nút đổi thành "Chuyển sang Bàn X"', (tester) async {
      _usePhone(tester);
      await _pump(tester, TransferTableScreen(currentTableId: servingTable.id));

      expect(find.text('Chọn bàn muốn chuyển đến'), findsWidgets);
      final target = MockData.tables.firstWhere((t) => t.status == TableStatus.empty);
      await tester.tap(find.bySemanticsLabel(RegExp('^${target.number},')));
      await tester.pumpAndSettle();

      expect(find.text('Chuyển sang ${target.number}'), findsOneWidget);
    });

    testWidgets('Gộp bàn: chọn thêm bàn thì hiện chip và đếm số bàn', (tester) async {
      _usePhone(tester);
      await _pump(tester, MergeTableScreen(initialTableId: servingTable.id));

      expect(find.text('Đã chọn 1 bàn'), findsOneWidget);
      final other = MockData.tables.firstWhere((t) => t.id != servingTable.id);
      await tester.tap(find.bySemanticsLabel(RegExp('^${other.number},')));
      await tester.pumpAndSettle();

      expect(find.text('Đã chọn 2 bàn'), findsOneWidget);
      expect(find.text(other.number), findsOneWidget);
    });

    testWidgets('Mục "Đơn đang phục vụ" ở tab Cá nhân chuyển tab thay vì mở màn mới', (tester) async {
      _usePhone(tester);
      await _pump(tester, const OrderStaffShell());

      AppBottomNav nav() => tester.widget<AppBottomNav>(find.byType(AppBottomNav));

      await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text('Cá nhân')));
      await tester.pumpAndSettle();
      expect(nav().currentIndex, StaffTab.profile.index);

      await tester.tap(
        find.descendant(of: find.byType(StaffProfileScreen), matching: find.text('Đơn đang phục vụ')),
      );
      await tester.pumpAndSettle();

      // Vẫn ở route đầu tiên (không đẩy thêm màn), tab Đang phục vụ đang được chọn.
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
      expect(nav().currentIndex, StaffTab.serving.index);
    });
  });
}
