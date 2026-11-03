import 'package:flutter/material.dart';

import '../../data/cart_store.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_bottom_nav.dart';
import 'booking_table_screen.dart';
import 'customer_home_screen.dart';
import 'customer_profile_screen.dart';
import 'menu_screen.dart';
import 'my_bookings_screen.dart';
import 'picked_foods_bar.dart';

/// Các tab của vai trò Khách hàng, đúng thứ tự trên thanh điều hướng.
enum CustomerTab { home, menu, booking, bookings, account }

/// Khung điều hướng (Bottom Navigation) cho vai trò Khách hàng:
/// Trang chủ, Thực đơn, Đặt bàn, Lịch đặt, Tài khoản.
///
/// Khách chỉ gọi món qua app bằng cách **đặt món trước khi đặt bàn**; gọi món
/// tại quán do Nhân viên Order nhập (app không biết khách đang ngồi bàn nào).
/// Vì vậy:
/// - Món chọn ở Trang chủ / Thực đơn được giữ trong [AppCart.customer] và hiện
///   ở [PickedFoodsBar] ngay trên thanh điều hướng; nút trên thanh mở tab Đặt bàn.
/// - Tab "Lịch đặt" (trước là "Đơn hàng") liệt kê các lượt đặt bàn kèm món đặt trước.
///   Lịch sử đơn đã ăn vẫn xem được ở tab Tài khoản → "Lịch sử đơn hàng".
class CustomerShell extends StatefulWidget {
  /// Tab mở đầu tiên, vd mở thẳng tab Lịch đặt sau khi đặt bàn thành công.
  final CustomerTab initialTab;

  const CustomerShell({super.key, this.initialTab = CustomerTab.home});

  /// Chuyển sang một tab từ bất kỳ màn hình con nào bên trong khung này.
  /// Trả về `false` nếu màn hình gọi không nằm trong [CustomerShell]
  /// (vd: khi được mở riêng trong test) để nơi gọi tự xử lý phương án khác.
  static bool goTo(BuildContext context, CustomerTab tab) {
    final state = context.findAncestorStateOfType<_CustomerShellState>();
    if (state == null) return false;
    state._selectTab(tab.index);
    return true;
  }

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> with SingleTickerProviderStateMixin {
  late int _index = widget.initialTab.index;

  /// Điều khiển hiệu ứng mờ dần mỗi khi đổi tab.
  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: 1,
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);

  static const _tabs = [
    CustomerHomeScreen(),
    MenuScreen(),
    BookingTableScreen(),
    MyBookingsScreen(),
    CustomerProfileScreen(),
  ];

  /// Thanh món đã chọn chỉ hiện ở hai tab có nút "+" chọn món.
  bool get _showPickedBar =>
      !AppCart.customer.isEmpty && (_index == CustomerTab.home.index || _index == CustomerTab.menu.index);

  @override
  void initState() {
    super.initState();
    AppCart.customer.addListener(_onPicksChanged);
  }

  @override
  void dispose() {
    AppCart.customer.removeListener(_onPicksChanged);
    _fadeController.dispose();
    super.dispose();
  }

  void _onPicksChanged() => setState(() {});

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    _fadeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FadeTransition bọc ngoài IndexedStack: đổi tab có hiệu ứng mờ dần
      // nhưng các tab vẫn giữ nguyên trạng thái (không dựng lại).
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(_fade),
          child: IndexedStack(index: _index, children: _tabs),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thanh món đã chọn trượt ra khi có món, thu lại khi danh sách trống.
          AnimatedSize(
            duration: AppMotion.normal,
            curve: Curves.easeOutCubic,
            child: _showPickedBar
                ? PickedFoodsBar(
                    picks: AppCart.customer,
                    onBook: () => _selectTab(CustomerTab.booking.index),
                  )
                : const SizedBox(width: double.infinity),
          ),
          AppBottomNav(
            currentIndex: _index,
            onTap: _selectTab,
            items: const [
              AppNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Trang chủ'),
              AppNavItem(
                  icon: Icons.restaurant_outlined, activeIcon: Icons.restaurant_rounded, label: 'Thực đơn'),
              AppNavItem(
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today_rounded,
                  label: 'Đặt bàn'),
              AppNavItem(
                  icon: Icons.event_note_outlined, activeIcon: Icons.event_note_rounded, label: 'Lịch đặt'),
              AppNavItem(
                  icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Tài khoản'),
            ],
          ),
        ],
      ),
    );
  }
}
