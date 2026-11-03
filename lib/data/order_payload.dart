import '../core/api/api_exception.dart';
import '../models/order_item.dart';

/// Id trên server là số. Id không phải số (dữ liệu mẫu như `f1`, `t1`) nghĩa là dữ liệu chưa
/// đồng bộ với máy chủ nên báo lỗi dễ hiểu thay vì gửi dữ liệu sai.
int serverId(String id, String label) =>
    int.tryParse(id) ??
    (throw ApiException(
        '"$label" chưa đồng bộ với máy chủ. Hãy kéo để làm mới hoặc đăng nhập lại rồi thử lại.'));

/// Danh sách món gửi lên server (đơn hàng, món đặt trước). Chỉ gửi mã món, số lượng, tùy chọn,
/// ghi chú; giá luôn do server tính.
List<Map<String, dynamic>> orderItemsPayload(List<OrderItem> items) => [
      for (final item in items)
        {
          'food_id': serverId(item.foodId, item.foodName),
          'quantity': item.quantity,
          if (item.selectedOptions.isNotEmpty)
            'option_ids': [for (final o in item.selectedOptions) serverId(o.id, o.name)],
          if (item.note.trim().isNotEmpty) 'note': item.note.trim(),
        },
    ];
