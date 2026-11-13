import '../core/api/api_client.dart';
import '../models/promotion.dart';

/// Repository cho các thao tác của Nhân viên Order và Thu ngân liên quan đến
/// bàn ăn và đơn hàng. Gọi thẳng đến Laravel REST API.
class OrderStaffRepository {
  OrderStaffRepository._();
  static final instance = OrderStaffRepository._();

  // ── Bàn ────────────────────────────────────────────────────────────────────

  /// Chuyển khách + toàn bộ đơn đang phục vụ từ [tableId] sang [targetTableId].
  ///
  /// Yêu cầu: [tableId] đang ở trạng thái `serving`, [targetTableId] đang trống.
  /// Server trả lỗi 422 nếu không đáp ứng điều kiện.
  Future<void> transferTable(
    String tableId, {
    required String targetTableId,
  }) async {
    await ApiClient.instance.post(
      '/tables/$tableId/transfer',
      // Backend expects 'to_table_id' (see TableOperationController@transfer).
      body: {'to_table_id': targetTableId},
    );
  }

  /// Gộp nhiều bàn nguồn ([sourceTableIds]) vào bàn đích [targetTableId].
  ///
  /// Với mỗi bàn nguồn, gọi `POST /tables/{source}/merge` để server chuyển
  /// tất cả món từ đơn nguồn sang đơn đích, sau đó giải phóng bàn nguồn.
  Future<void> mergeIntoTable(
    String targetTableId, {
    required List<String> sourceTableIds,
  }) async {
    for (final sourceId in sourceTableIds) {
      await ApiClient.instance.post(
        '/tables/$sourceId/merge',
        body: {'target_table_id': targetTableId},
      );
    }
  }

  // ── Đơn hàng ────────────────────────────────────────────────────────────────

  /// Lý do hủy đơn (khớp App\\Enums\\CancelReason ở backend). "Khác" thì bắt buộc ghi chú.
  static const cancelReasons = {
    'wrong_entry': 'Nhập nhầm',
    'customer_left': 'Khách bỏ về',
    'out_of_stock': 'Hết món',
    'other': 'Khác',
  };

  /// Huỷ đơn [orderId] kèm lý do [reason] (khóa trong [cancelReasons]) và ghi chú [note].
  ///
  /// Chỉ Thu ngân / Admin mới có quyền huỷ, và chỉ huỷ được đơn chưa thanh toán.
  /// Server lưu lý do, người hủy, thời điểm; trả 403 nếu sai vai trò, 422 nếu thiếu lý do / đơn đã thanh toán.
  Future<void> cancelOrder(String orderId, {required String reason, String? note}) async {
    await ApiClient.instance.patch('/orders/$orderId/cancel', body: {
      'reason': reason,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  // ── Khuyến mãi ──────────────────────────────────────────────────────────────

  /// Lấy danh sách khuyến mãi đang hoạt động để hiển thị trên màn hình
  /// thanh toán. Thu ngân chọn voucher phù hợp trước khi xác nhận.
  Future<List<Promotion>> fetchActivePromotions() async {
    final res = await ApiClient.instance.get(
      '/promotions',
      query: {'status': 'active'},
    );
    return res.list.map((j) => Promotion.fromApiJson(j)).toList();
  }
}
