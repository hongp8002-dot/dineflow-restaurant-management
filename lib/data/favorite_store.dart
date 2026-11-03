import 'package:flutter/foundation.dart';

/// Danh sách món yêu thích của khách hàng.
///
/// Giai đoạn chỉ làm giao diện: lưu trong RAM (mất khi tắt app), giống
/// [CartStore]. Khi có backend sẽ đồng bộ với API yêu thích của khách hàng.
class FavoriteStore extends ChangeNotifier {
  FavoriteStore._();

  /// Instance dùng chung cho toàn app.
  static final FavoriteStore instance = FavoriteStore._();

  // LinkedHashSet giữ thứ tự thêm vào để màn Yêu thích hiện món mới nhất cuối.
  final Set<String> _foodIds = <String>{};

  List<String> get foodIds => List.unmodifiable(_foodIds);

  bool isFavorite(String foodId) => _foodIds.contains(foodId);

  /// Thêm hoặc bỏ yêu thích; trả về trạng thái mới (true = đang yêu thích).
  bool toggle(String foodId) {
    final added = _foodIds.add(foodId);
    if (!added) _foodIds.remove(foodId);
    notifyListeners();
    return added;
  }

  void remove(String foodId) {
    if (_foodIds.remove(foodId)) notifyListeners();
  }
}
