import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/app_navigator.dart';
import 'app/routes.dart';
import 'core/api/api_client.dart';
import 'core/session/session_store.dart';
import 'data/app_data.dart';
import 'data/auth_repository.dart';
import 'data/mock_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  await MockData.loadFoods();

  // Khôi phục phiên đăng nhập: còn dùng được thì vào thẳng màn chính của vai trò.
  await SessionStore.instance.load();
  // Chờ tối đa 4 giây: server chậm/không phản hồi thì vẫn mở app bằng phiên đã lưu.
  final user = await AuthRepository.instance
      .restore()
      .timeout(const Duration(seconds: 4), onTimeout: () => SessionStore.instance.user);
  ApiClient.instance.onSessionExpired = AppNavigator.onSessionExpired;

  // Còn phiên: tải dữ liệu thật (thực đơn...) trước khi dựng giao diện. Quá 6 giây thì
  // vẫn mở app (phần chưa tải xong sẽ tự cập nhật vào dữ liệu khi server trả lời).
  if (user != null) {
    await AppData.load().timeout(const Duration(seconds: 6), onTimeout: () => null);
  }

  runApp(DineFlowApp(initialRoute: user == null ? AppRoutes.login : AppRoutes.homeFor(user.role)));
}
