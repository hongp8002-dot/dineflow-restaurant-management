import 'package:flutter/material.dart';

import '../../widgets/app_animations.dart';
import '../../widgets/app_bottom_nav.dart';
import 'order_entry_screen.dart';
import 'serving_orders_screen.dart';
import 'staff_profile_screen.dart';
import 'table_management_screen.dart';

/// Các tab của Nhân viên Order, theo thứ tự trên thanh điều hướng.
enum StaffTab { tables, order, serving, profile }

/// Khung điều hướng cho Nhân viên Order: Bàn, Order, Đang phục vụ, Cá nhân.
class OrderStaffShell extends StatefulWidget {
  const OrderStaffShell({super.key});

  /// Chuyển sang một tab khác từ màn con nằm trong khung (vd mục "Sơ đồ bàn"
  /// ở tab Cá nhân). Trả về false nếu màn hiện tại không nằm trong khung.
  static bool goTo(BuildContext context, StaffTab tab) {
    final state = context.findAncestorStateOfType<_OrderStaffShellState>();
    if (state == null) return false;
    state._selectTab(tab.index);
    return true;
  }

  @override
  State<OrderStaffShell> createState() => _OrderStaffShellState();
}

class _OrderStaffShellState extends State<OrderStaffShell> with SingleTickerProviderStateMixin {
  int _index = 0;

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: 1,
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);

  static const _tabs = [
    TableManagementScreen(),
    OrderEntryScreen(),
    ServingOrdersScreen(),
    StaffProfileScreen(),
  ];

  static const _items = [
    AppNavItem(icon: Icons.table_bar_outlined, activeIcon: Icons.table_bar, label: 'Bàn'),
    AppNavItem(icon: Icons.restaurant_outlined, activeIcon: Icons.restaurant, label: 'Order'),
    AppNavItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment, label: 'Đang phục vụ'),
    AppNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Cá nhân'),
  ];

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    _fadeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(_fade),
          child: IndexedStack(index: _index, children: _tabs),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        items: _items,
        currentIndex: _index,
        onTap: _selectTab,
      ),
    );
  }
}
