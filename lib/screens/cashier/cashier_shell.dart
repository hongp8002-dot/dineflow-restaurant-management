import 'package:flutter/material.dart';

import '../../widgets/app_animations.dart';
import '../../widgets/app_bottom_nav.dart';
import 'cashier_dashboard_screen.dart';
import 'cashier_profile_screen.dart';
import 'history_screen.dart';
import 'pending_payment_screen.dart';
import 'shift_screen.dart';

/// Các tab của Thu ngân, theo thứ tự trên thanh điều hướng.
enum CashierTab { dashboard, pending, history, shift, profile }

/// Khung điều hướng cho Thu ngân: Tổng quan, Chờ thanh toán, Lịch sử, Ca làm, Cá nhân.
class CashierShell extends StatefulWidget {
  const CashierShell({super.key});

  /// Chuyển sang một tab khác từ màn con nằm trong khung (vd ô "Truy cập
  /// nhanh" ở Tổng quan). Trả về false nếu màn hiện tại không nằm trong khung.
  static bool goTo(BuildContext context, CashierTab tab) {
    final state = context.findAncestorStateOfType<_CashierShellState>();
    if (state == null) return false;
    state._selectTab(tab.index);
    return true;
  }

  @override
  State<CashierShell> createState() => _CashierShellState();
}

class _CashierShellState extends State<CashierShell> with SingleTickerProviderStateMixin {
  int _index = 0;

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: AppMotion.normal,
    value: 1,
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);

  static const _tabs = [
    CashierDashboardScreen(),
    PendingPaymentScreen(),
    HistoryScreen(),
    ShiftScreen(),
    CashierProfileScreen(),
  ];

  static const _items = [
    AppNavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'Tổng quan'),
    AppNavItem(
        icon: Icons.hourglass_empty_rounded, activeIcon: Icons.hourglass_bottom_rounded, label: 'Chờ TT'),
    AppNavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Lịch sử'),
    AppNavItem(icon: Icons.badge_outlined, activeIcon: Icons.badge, label: 'Ca làm'),
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
