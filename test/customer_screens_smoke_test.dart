import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dineflow/data/cart_store.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/screens/auth/login_screen.dart';
import 'package:dineflow/screens/auth/register_screen.dart';
import 'package:dineflow/screens/customer/booking_checkout.dart';
import 'package:dineflow/screens/customer/booking_confirmation_screen.dart';
import 'package:dineflow/screens/customer/booking_payment_screen.dart';
import 'package:dineflow/screens/customer/customer_order_actions.dart';
import 'package:dineflow/screens/customer/pre_order_screen.dart';
import 'package:dineflow/screens/customer/booking_table_screen.dart';
import 'package:dineflow/screens/customer/customer_profile_screen.dart';
import 'package:dineflow/screens/customer/customer_shell.dart';
import 'package:dineflow/screens/customer/food_detail_screen.dart';
import 'package:dineflow/screens/customer/member_qr_screen.dart';
import 'package:dineflow/screens/customer/menu_screen.dart';
import 'package:dineflow/screens/customer/my_bookings_screen.dart';
import 'package:dineflow/screens/customer/order_detail_screen.dart';
import 'package:dineflow/screens/customer/order_history_screen.dart';
import 'package:dineflow/theme/app_colors.dart';
import 'package:dineflow/theme/app_theme.dart';

/// Smoke test giao diện: dựng từng màn hình của vai trò Khách hàng trên hai cỡ
/// máy phổ biến và bắt lỗi tràn layout (RenderFlex overflowed).
/// Mục đích: khi chỉnh style/animation, nếu một khối bị tràn khỏi màn hình
/// thì test sẽ đỏ ngay thay vì phải mở app kiểm tra bằng mắt.
void main() {
  // 360x800: máy phổ thông hiện nay. 320x640: máy nhỏ/cũ, dễ lộ lỗi tràn nhất.
  const sizes = <String, Size>{
    'may pho thong 360x800': Size(360, 800),
    'may nho 320x640': Size(320, 640),
  };

  final screens = <String, Widget Function()>{
    // Màn vào app (dựng lại theo mockup Đăng nhập).
    'LoginScreen': () => const LoginScreen(),
    'RegisterScreen': () => const RegisterScreen(),
    'CustomerShell (trang chu + bottom nav)': () => const CustomerShell(),
    // Thanh "món đã chọn" hiện trên bottom nav khi khách đã chọn món ở Trang chủ / Thực đơn.
    'CustomerShell (co mon da chon)': () {
      addOneFood(AppCart.customer, MockData.foods[0]);
      addOneFood(AppCart.customer, MockData.foods[1]);
      return const CustomerShell();
    },
    'CustomerShell (tab Lich dat)': () => const CustomerShell(initialTab: CustomerTab.bookings),
    'MenuScreen': () => const MenuScreen(),
    'OrderHistoryScreen': () => const OrderHistoryScreen(),
    'CustomerProfileScreen': () => const CustomerProfileScreen(),
    'MemberQrScreen': () => const MemberQrScreen(),
    'MyBookingsScreen': () => const MyBookingsScreen(),
    'BookingTableScreen': () => const BookingTableScreen(),
    // Luồng đặt bàn qua app: dựng bước 2, 3 với một lượt đang giữ bàn (có 1 món đặt trước).
    'PreOrderScreen': () {
      BookingCheckout.instance.start(MockData.upcomingReservations.first);
      addOneFood(BookingCheckout.instance.preOrder, MockData.foods.first);
      return const PreOrderScreen();
    },
    'BookingPaymentScreen': () {
      BookingCheckout.instance.start(MockData.upcomingReservations.first);
      addOneFood(BookingCheckout.instance.preOrder, MockData.foods.first);
      return const BookingPaymentScreen();
    },
    'FoodDetailScreen': () => FoodDetailScreen(foodId: MockData.foods.first.id),
    'OrderDetailScreen': () => OrderDetailScreen(orderId: MockData.orders.first.id),
    'BookingConfirmationScreen': () =>
        BookingConfirmationScreen(reservation: MockData.upcomingReservations.first),
  };

  Future<void> pumpScreen(WidgetTester tester, Size size, Widget Function() builder) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(AppCart.customer.clear);

    await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: builder()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  }

  sizes.forEach((sizeName, size) {
    group('Kích thước $sizeName', () {
      screens.forEach((screenName, builder) {
        testWidgets(
            '$screenName dựng được, không tràn layout', (tester) => pumpScreen(tester, size, builder));
      });
    });
  });

  // Chế độ tối: dựng lại từng màn với bảng màu tối (đổi ở trang Tài khoản).
  group('Chế độ tối 360x800', () {
    setUp(() => AppColors.usePalette(AppPalette.dark));
    tearDown(() => AppColors.usePalette(AppPalette.light));
    screens.forEach((screenName, builder) {
      testWidgets('$screenName dựng được ở chế độ tối',
          (tester) => pumpScreen(tester, const Size(360, 800), builder));
    });
  });
}
