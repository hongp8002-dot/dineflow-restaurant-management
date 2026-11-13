import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../models/invoice.dart';
import '../models/promotion.dart';

/// Hóa đơn và thanh toán (thu ngân, admin).
class InvoiceRepository {
  InvoiceRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  /// Không phải `final` để test thay bằng bản giả.
  static InvoiceRepository instance = InvoiceRepository();

  final ApiClient _api;

  /// 100 hóa đơn đã thanh toán gần nhất (mới nhất trước).
  Future<List<Invoice>> fetchAll() async {
    final res = await _api.get('/invoices', query: {'per_page': '100'});
    return [for (final i in res.list) Invoice.fromApiJson(i)];
  }

  /// Thanh toán đơn theo quy tắc Kiểu A.
  ///
  /// - Không dùng điểm để trừ tiền (đã bỏ points_used).
  /// - Giảm = max(giảm theo hạng, giảm theo voucher) – server tự tính.
  /// - Ném [ApiException] kèm lý do nếu vi phạm (voucher hết, đơn đã trả, chưa mở ca...).
  Future<Invoice> pay(
    String orderId, {
    required PaymentMethod method,
    String? promotionCode,
    String? memberCode,
  }) async {
    final id = int.tryParse(orderId);
    if (id == null) {
      throw const ApiException(
          'Đơn này chưa đồng bộ với máy chủ. Hãy kéo để làm mới hoặc đăng nhập lại.');
    }

    final res = await _api.post('/orders/$id/pay', body: {
      'payment_method': method.name,
      if (promotionCode != null && promotionCode.isNotEmpty) 'promotion_code': promotionCode,
      // Mã thành viên thu ngân quét / nhập: server gắn khách vào đơn để giảm theo hạng và cộng điểm
      if (memberCode != null && memberCode.isNotEmpty) 'member_code': memberCode,
    });
    return Invoice.fromApiJson(res.map);
  }

  /// Voucher đang trong thời gian hiệu lực.
  Future<List<Promotion>> fetchAvailablePromotions() async {
    final res = await _api.get('/promotions');
    return [for (final p in res.list) Promotion.fromApiJson(p)];
  }
}
