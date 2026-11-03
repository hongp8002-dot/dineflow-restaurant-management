import '../core/api/api_client.dart';
import '../models/table_model.dart';

/// Danh sách bàn và trạng thái hiện tại lấy từ API.
class TableRepository {
  TableRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  /// Không phải `final` để test thay bằng bản giả.
  static TableRepository instance = TableRepository();

  final ApiClient _api;

  Future<List<TableModel>> fetch() async {
    final res = await _api.get('/tables');
    return [for (final t in res.list) TableModel.fromApiJson(t)];
  }
}
