import '../core/api/api_client.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import 'order_payload.dart';

/// Đơn hàng qua API: nhân viên/thu ngân thấy mọi đơn, khách chỉ thấy đơn của mình (server tự lọc).
class OrderRepository {
  OrderRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  /// Không phải `final` để test thay bằng bản giả.
  static OrderRepository instance = OrderRepository();

  final ApiClient _api;

  /// 100 đơn mới nhất.
  Future<List<Order>> fetchAll() async {
    final res = await _api.get('/orders', query: {'per_page': '100'});
    return [for (final o in res.list) Order.fromApiJson(o)];
  }

  /// Tạo đơn (nhân viên: tại [tableId]; khách: không gắn bàn).
  ///
  /// Bàn đang có đơn mở thì server thêm món vào đơn đó (một bàn chỉ có một đơn mở);
  /// [message] cho biết trường hợp nào để hiện cho người dùng.
  /// Giá luôn do server tính nên không gửi giá lên.
  Future<({Order order, String message})> create({
    String? tableId,
    required List<OrderItem> items,
    String? note,
  }) async {
    final res = await _api.post('/orders', body: {
      if (tableId != null) 'table_id': serverId(tableId, 'Bàn'),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'items': orderItemsPayload(items),
    });

    return (order: Order.fromApiJson(res.map), message: res.message);
  }

  /// Đổi trạng thái bếp/phục vụ. Server chỉ cho đi tiến (đã đặt → chuẩn bị → phục vụ → hoàn thành)
  /// hoặc hủy khi chưa thanh toán; vi phạm thì ném [ApiException] kèm lý do.
  Future<Order> updateStatus(String orderId, OrderStatus status) async {
    final res = await _api.patch('/orders/${serverId(orderId, 'Đơn')}/status', body: {'status': status.name});
    return Order.fromApiJson(res.map);
  }
}
