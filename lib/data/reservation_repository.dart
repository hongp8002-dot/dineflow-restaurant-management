import '../core/api/api_client.dart';
import '../models/invoice.dart';
import '../models/order_item.dart';
import '../models/reservation.dart';
import '../models/table_model.dart';
import 'order_payload.dart';

/// Đặt bàn của khách qua API.
///
/// Luồng đặt bàn qua app có 3 bước: [hold] (giữ bàn 10 phút) → đặt món trước → [confirm] (thanh toán xong).
/// Khách bỏ giữa chừng thì [cancel] nhả bàn; quên hoặc tắt app thì server tự hủy khi hết hạn giữ bàn.
class ReservationRepository {
  ReservationRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  /// Không phải `final` để test thay bằng bản giả.
  static ReservationRepository instance = ReservationRepository();

  final ApiClient _api;

  /// Mọi lượt đặt của khách đang đăng nhập (mới nhất trước), kể cả đã hủy / hoàn thành.
  Future<List<Reservation>> fetchMine() async {
    final res = await _api.get('/reservations/my');
    return [for (final r in res.list) Reservation.fromApiJson(r)];
  }

  /// Bước 1: GIỮ bàn (chưa xác nhận). Server từ chối (422) nếu bàn không đủ chỗ cho [guestCount],
  /// các bàn khác khu vực, hoặc đã có người đặt trong khung giờ đó.
  Future<Reservation> hold({
    required List<TableModel> tables,
    required DateTime dateTime,
    required int guestCount,
    String? note,
  }) async {
    final res = await _api.post('/reservations', body: {
      'table_ids': [for (final t in tables) serverId(t.id, t.number)],
      // Gửi giờ UTC để không phụ thuộc múi giờ của điện thoại; server đổi về múi giờ của quán.
      'date_time': dateTime.toUtc().toIso8601String(),
      'guest_count': guestCount,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'hold': true,
    });
    return Reservation.fromApiJson(res.map);
  }

  /// Bước cuối: xác nhận lượt đặt đang giữ bàn, kèm món đặt trước ([items] rỗng = không đặt món).
  /// Giá món do server tính. Hết hạn giữ bàn / món hết hàng thì ném `ApiException`.
  Future<Reservation> confirm(
    String reservationId, {
    List<OrderItem> items = const [],
    PaymentMethod? payment,
  }) async {
    final res = await _api.post('/reservations/${serverId(reservationId, 'Lượt đặt bàn')}/confirm', body: {
      if (items.isNotEmpty) ...{
        'pre_order_items': orderItemsPayload(items),
        'pre_order_payment': (payment ?? PaymentMethod.cash).name,
      },
    });
    return Reservation.fromApiJson(res.map);
  }

  /// Hủy lượt đặt. Khách hủy lượt của mình; NV Order / Thu ngân / Admin hủy được mọi lượt
  /// (vd khách không đến). Tiền cọc (nếu có) không được hoàn lại.
  Future<Reservation> cancel(String reservationId) async {
    final res = await _api.patch('/reservations/${serverId(reservationId, 'Lượt đặt bàn')}/cancel');
    return Reservation.fromApiJson(res.map);
  }

  /// Lịch đặt bàn của nhà hàng trong ngày [date] (NV Order, Thu ngân, Admin), sớm nhất trước.
  Future<List<Reservation>> fetchForDate(DateTime date) async {
    final day = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final res = await _api.get('/reservations', query: {'date': day});
    return [for (final r in res.list) Reservation.fromApiJson(r)];
  }

  /// Nhận bàn khi khách đặt trước tới quán (NV Order, Thu ngân).
  /// Server mở bàn, tạo đơn từ món đặt trước và chuyển lượt đặt sang "Đã hoàn thành".
  /// Trả về lượt đặt đã cập nhật và id đơn hàng vừa tạo.
  Future<({Reservation reservation, String orderId, String message})> checkIn(String reservationId) async {
    final res = await _api.post('/reservations/${serverId(reservationId, 'Lượt đặt bàn')}/check-in');
    final data = res.map;
    return (
      reservation: Reservation.fromApiJson(data['reservation'] as Map<String, dynamic>),
      orderId: (data['order'] as Map<String, dynamic>)['id'].toString(),
      message: res.message,
    );
  }
}
