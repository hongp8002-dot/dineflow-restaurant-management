import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'routes.dart';

/// Điều hướng không cần BuildContext: dùng khi phiên hết hạn (do tầng API báo)
/// và khi đăng xuất từ bất kỳ màn nào.
class AppNavigator {
  AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  /// Về màn Đăng nhập và xóa toàn bộ lịch sử màn hình.
  static void toLogin() {
    key.currentState?.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  /// Token hết hạn / tài khoản bị khóa giữa chừng: về Đăng nhập kèm thông báo.
  static Future<void> onSessionExpired() async {
    toLogin();
    final context = key.currentContext;
    if (context != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.')),
      );
    }
  }
}

/// Đăng xuất (xóa token trên server và trên máy) rồi về màn Đăng nhập.
Future<void> signOut() async {
  await AuthRepository.instance.logout();
  AppNavigator.toLogin();
}
