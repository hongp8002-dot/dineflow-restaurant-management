import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dineflow/app/routes.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/models/order.dart';
import 'package:dineflow/models/promotion.dart';
import 'package:dineflow/screens/cashier/cashier_dashboard_screen.dart';
import 'package:dineflow/screens/cashier/cashier_profile_screen.dart';
import 'package:dineflow/screens/cashier/cashier_shell.dart';
import 'package:dineflow/screens/cashier/history_screen.dart';
import 'package:dineflow/screens/cashier/invoice_screen.dart';
import 'package:dineflow/screens/cashier/payment_screen.dart';
import 'package:dineflow/screens/cashier/pending_payment_screen.dart';
import 'package:dineflow/screens/cashier/shift_screen.dart';
import 'package:dineflow/theme/app_theme.dart';
import 'package:dineflow/utils/formatters.dart';
import 'package:dineflow/widgets/app_bottom_nav.dart';

void _usePhone(WidgetTester tester, [Size size = const Size(360, 800)]) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.current, onGenerateRoute: AppRoutes.onGenerateRoute, home: home),
  );
  await tester.pumpAndSettle();
}

/// Smoke test giao diện cho nhóm màn hình Thu ngân.
void main() {
  const sizes = <String, Size>{
    'may pho thong 360x800': Size(360, 800),
    'may nho 320x640': Size(320, 640),
  };

  final pendingOrder = MockData.pendingPaymentOrders.first;

  final screens = <String, Widget Function()>{
    'CashierShell': () => const CashierShell(),
    'CashierDashboardScreen': () => const CashierDashboardScreen(),
    'PendingPaymentScreen': () => const PendingPaymentScreen(),
    'ShiftScreen': () => const ShiftScreen(),
    'HistoryScreen': () => const HistoryScreen(),
    'CashierProfileScreen': () => const CashierProfileScreen(),
    'PaymentScreen': () => PaymentScreen(orderId: pendingOrder.id),
    'InvoiceScreen': () => InvoiceScreen(invoice: MockData.invoices.first),
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

  group('Chức năng Thu ngân', () {
    testWidgets('Chờ thanh toán phân biệt "Đang xử lý" và "Chưa thanh toán"', (tester) async {
      _usePhone(tester);
      await _pump(tester, const PendingPaymentScreen());

      final orders = MockData.pendingPaymentOrders;
      final processing = orders.where((o) => o.paymentStatus == PaymentStatus.pending).length;
      expect(find.text('${orders.length} đơn cần xử lý'), findsOneWidget);
      expect(find.text('Đang xử lý'), findsNWidgets(processing));
      expect(find.text('Chưa thanh toán'), findsNWidgets(orders.length - processing));
    });

    testWidgets('Thanh toán: chọn voucher thì giảm giá, xác nhận thì sang Hoá đơn', (tester) async {
      _usePhone(tester);
      await _pump(tester, PaymentScreen(orderId: pendingOrder.id));

      expect(find.text('Thanh toán · ${pendingOrder.tableNumber}'), findsOneWidget);

      final promo = MockData.promotions.firstWhere((p) => p.status == PromotionStatus.active);
      await tester.tap(find.text('${promo.code} · -${promo.percent}%'));
      await tester.pumpAndSettle();
      final discount = pendingOrder.subtotal * promo.percent / 100;
      expect(find.text('-${AppFormatters.currency(discount)}'), findsOneWidget);
      expect(find.text(AppFormatters.currency(pendingOrder.subtotal - discount)), findsOneWidget);

      // Ô phương thức nằm cuối danh sách: cuộn cho nó hiện hẳn trong vùng nhìn thấy.
      await tester.ensureVisible(find.text('QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QR'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xác nhận thanh toán'));
      await tester.pumpAndSettle();

      expect(find.text('Hóa đơn'), findsOneWidget);
      expect(find.text('Đã thanh toán · đơn #${pendingOrder.id.toUpperCase()}'), findsOneWidget);
      expect(find.text('QR'), findsOneWidget);
    });

    testWidgets('Ô "Truy cập nhanh" chuyển tab thay vì mở thêm màn', (tester) async {
      _usePhone(tester);
      await _pump(tester, const CashierShell());

      AppBottomNav nav() => tester.widget<AppBottomNav>(find.byType(AppBottomNav));
      expect(nav().currentIndex, CashierTab.dashboard.index);

      await tester.tap(
        find.descendant(of: find.byType(CashierDashboardScreen), matching: find.text('Lịch sử')),
      );
      await tester.pumpAndSettle();

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
      expect(nav().currentIndex, CashierTab.history.index);
    });
  });
}
