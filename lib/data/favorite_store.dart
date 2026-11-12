import 'package:flutter/foundation.dart';

import 'favorite_repository.dart';

/// Danh sách món yêu thích của khách hàng.
///
/// Dữ liệu được tải từ server sau khi đăng nhập (xem [AppData.load]).
/// [toggle] và [remove] cập nhật UI ngay (optimistic) rồi gọi API sau;
/// nếu API lỗi thì tự hoàn tác để UI luôn đúng với server.
class FavoriteStore extends ChangeNotifier {
  FavoriteStore._();

  /// Instance dùng chung cho toàn app.
  static final FavoriteStore instance = FavoriteStore._();

  final Set<String> _foodIds = <String>{};

  List<String> get foodIds => List.unmodifiable(_foodIds);

  bool isFavorite(String foodId) => _foodIds.contains(foodId);

  /// Nạp danh sách yêu thích từ server.
  /// Gọi sau khi đăng nhập (chỉ cho vai trò khách hàng).
  Future<void> loadFromApi() async {
    try {
      final ids = await FavoriteRepository.instance.fetchFoodIds();
      _foodIds
        ..clear()
        ..addAll(ids);
      notifyListeners();
    } catch (_) {
      // Lỗi mạng: giữ danh sách rỗng, không crash.
    }
  }

  /// Optimistic toggle: đổi UI ngay rồi gọi API.
  /// Trả về trạng thái mới (true = đang yêu thích).
  Future<bool> toggle(String foodId) async {
    final wasIn = _foodIds.contains(foodId);
    // Cập nhật ngay để icon tim phản hồi tức thì.
    if (wasIn) {
      _foodIds.remove(foodId);
    } else {
      _foodIds.add(foodId);
    }
    notifyListeners();

    try {
      await FavoriteRepository.instance.toggle(foodId);
    } catch (e) {
      // Hoàn tác nếu API thất bại.
      if (wasIn) {
        _foodIds.add(foodId);
      } else {
        _foodIds.remove(foodId);
      }
      notifyListeners();
      rethrow; // Cho UI biết lỗi để hiển thị thông báo
    }

    return _foodIds.contains(foodId);
  }

  /// Bỏ yêu thích từ nút ♥ trong màn Món yêu thích.
  void remove(String foodId) {
    if (!_foodIds.remove(foodId)) return;
    notifyListeners();
    // Gọi API; nếu lỗi thì hoàn tác (thêm lại vào Set).
    FavoriteRepository.instance.toggle(foodId).catchError((_) {
      _foodIds.add(foodId);
      notifyListeners();
      return false; // toggle() trả Future<bool>; giá trị này không được dùng
    });
  }

  /// Xóa khi đăng xuất để tránh lộ dữ liệu giữa các phiên.
  void clear() {
    _foodIds.clear();
    notifyListeners();
  }
}
