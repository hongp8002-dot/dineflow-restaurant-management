import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../models/app_notification.dart';

/// Giao tiếp với Laravel API cho thông báo in-app của khách hàng.
///
/// Endpoints:
///   GET  /api/customers/me/notifications
///   PATCH /api/customers/me/notifications/{id}/read
///   POST  /api/customers/me/notifications/read-all
class NotificationRepository {
  NotificationRepository._();
  static final instance = NotificationRepository._();

  final _client = ApiClient.instance;

  /// Số thông báo chưa đọc, hiển thị thành chấm số trên icon chuông ở Trang chủ.
  /// Widget lắng nghe bằng `ValueListenableBuilder` nên tự vẽ lại khi số thay đổi.
  final unreadCount = ValueNotifier<int>(0);

  /// Lấy danh sách thông báo (mới nhất trước) và cập nhật luôn số chưa đọc.
  Future<List<AppNotification>> fetchAll() async {
    final res = await _client.get('/customers/me/notifications');
    final list = res.list.map(AppNotification.fromJson).toList();
    unreadCount.value = list.where((n) => !n.isRead).length;
    return list;
  }

  /// Tải lại số chưa đọc cho icon chuông. Lỗi mạng thì giữ số cũ,
  /// vì chấm đỏ chỉ là phần phụ, không đáng chặn màn hình bằng thông báo lỗi.
  Future<void> refreshUnreadCount() async {
    try {
      await fetchAll();
    } catch (_) {}
  }

  /// Đánh dấu một thông báo đã đọc.
  Future<void> markRead(String id) async {
    await _client.patch('/customers/me/notifications/$id/read');
    if (unreadCount.value > 0) unreadCount.value--;
  }

  /// Đánh dấu tất cả thông báo đã đọc.
  Future<void> markAllRead() async {
    await _client.post('/customers/me/notifications/read-all');
    unreadCount.value = 0;
  }

  /// Xóa khi đăng xuất để tài khoản sau không thấy số của tài khoản trước.
  void clear() => unreadCount.value = 0;
}
