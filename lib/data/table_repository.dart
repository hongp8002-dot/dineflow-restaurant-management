import '../core/api/api_client.dart';
import '../models/table_model.dart';

/// Danh sách bàn và trạng thái hiện tại lấy từ API.
class TableRepository {
  TableRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  /// Không phải `final` để test thay bằng bản giả.
  static TableRepository instance = TableRepository();

  final ApiClient _api;

  /// Tải trạng thái bàn HIỆN TẠI.
  /// Dùng bởi NV Order, Admin và phần refresh tổng quát của app.
  Future<List<TableModel>> fetch() async {
    final res = await _api.get('/tables');
    return [for (final t in res.list) TableModel.fromApiJson(t)];
  }

  /// Tải khả năng đặt bàn tại một thời điểm CỤ THỂ trong tương lai.
  ///
  /// Gọi API `/tables/available?datetime=...` và trả về danh sách bàn
  /// với field `available` cho biết bàn có trống vào đúng ngày/giờ khách chọn hay không.
  ///
  /// Dùng bởi màn hình Đặt bàn của khách: sau khi chọn ngày + giờ, gọi hàm này
  /// để hiển thị trạng thái bàn ĐÚNG thay vì đọc MockData (trạng thái hiện tại).
  Future<List<TableModel>> fetchAvailability(DateTime dateTime) async {
    // Gửi giờ UTC giống hệt lúc giữ bàn (ReservationRepository.hold) để server
    // đổi về cùng một múi giờ của quán → kiểm tra bàn trống và đặt bàn luôn khớp nhau.
    final res = await _api.get('/tables/available', query: {
      'datetime': dateTime.toUtc().toIso8601String(),
    });
    return [for (final t in res.list) TableModel.fromAvailabilityJson(t)];
  }
}
