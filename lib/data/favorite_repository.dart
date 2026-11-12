import '../core/api/api_client.dart';

/// Gọi API yêu thích của khách hàng.
/// Chỉ dùng cho vai trò customer; các vai trò khác không cần.
class FavoriteRepository {
  FavoriteRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static final FavoriteRepository instance = FavoriteRepository();

  final ApiClient _api;

  /// Trả về danh sách food_id khách đang yêu thích (chuỗi).
  Future<List<String>> fetchFoodIds() async {
    final res = await _api.get('/customers/me/favorites');
    return res.list.map((f) => f['id'].toString()).toList();
  }

  /// Toggle yêu thích; trả về trạng thái mới (true = đang yêu thích).
  Future<bool> toggle(String foodId) async {
    final res = await _api.post('/customers/me/favorites/$foodId');
    return res.map['favorited'] as bool;
  }
}
