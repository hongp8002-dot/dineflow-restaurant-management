import '../../data/cart_store.dart';
import '../../models/food.dart';
import '../../models/order_item.dart';

/// Thêm một phần món vào [store]; nếu đã có dòng cùng món (chưa có tuỳ chọn hay
/// ghi chú riêng) thì tăng số lượng dòng đó. Dòng đã có tuỳ chọn hoặc ghi chú
/// riêng (vd "ít đá") được coi là suất khác nên vẫn giữ tách ra.
///
/// Dùng cho nút "+" ở Thực đơn / Trang chủ (chọn món để đặt trước khi đặt bàn)
/// và danh sách ở bước "Đặt món trước"; hai nơi dùng chung [AppCart.customer].
void addOneFood(CartStore store, Food food) {
  final existingIndex = store.items.indexWhere(
    (item) => item.foodId == food.id && item.note.isEmpty && item.selectedOptions.isEmpty,
  );

  if (existingIndex != -1) {
    final existing = store.items[existingIndex];
    store.updateQuantity(existing.id, existing.quantity + 1);
  } else {
    store.addItem(OrderItem(
      id: '${food.id}-${DateTime.now().millisecondsSinceEpoch}',
      foodId: food.id,
      foodName: food.name,
      price: food.price,
      quantity: 1,
    ));
  }
}
