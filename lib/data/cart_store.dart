import 'package:flutter/foundation.dart';

import '../models/order_item.dart';
import '../models/promotion.dart';

/// Bộ nhớ giỏ hàng đơn giản (chỉ lưu trong RAM, mất khi tắt app).
/// Dùng ChangeNotifier (có sẵn trong Flutter) thay vì thêm package quản lý
/// state phức tạp, vì ở giai đoạn UI-only chưa cần thiết.
class CartStore extends ChangeNotifier {
  final List<OrderItem> _items = [];
  Promotion? _appliedPromotion;

  List<OrderItem> get items => List.unmodifiable(_items);
  Promotion? get appliedPromotion => _appliedPromotion;

  bool get isEmpty => _items.isEmpty;
  int get totalQuantity => _items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => _items.fold(0, (sum, i) => sum + i.total);

  double get promotionDiscount => _appliedPromotion == null ? 0 : subtotal * _appliedPromotion!.percent / 100;

  // Không còn "dùng điểm trừ tiền": nhóm chọn quy tắc giảm theo hạng (Kiểu A),
  // xem data/loyalty_rules.dart.
  double get total => (subtotal - promotionDiscount).clamp(0, double.infinity);

  void addItem(OrderItem item) {
    _items.add(item);
    notifyListeners();
  }

  void updateQuantity(String itemId, int quantity) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  void updateNote(String itemId, String note) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(note: note);
    notifyListeners();
  }

  void removeItem(String itemId) {
    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
  }

  void applyPromotion(Promotion? promotion) {
    _appliedPromotion = promotion;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _appliedPromotion = null;
    notifyListeners();
  }
}

/// Instance dùng chung trong toàn app cho giỏ hàng Khách hàng
/// và giỏ order tại bàn của Order Staff (2 luồng tách biệt).
class AppCart {
  AppCart._();
  static final CartStore customer = CartStore();
  static final CartStore staffOrder = CartStore();
}
