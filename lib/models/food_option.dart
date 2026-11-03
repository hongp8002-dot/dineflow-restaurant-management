/// Loại tùy chọn của món: size hoặc topping.
enum FoodOptionType { size, topping }

/// Một lựa chọn tùy chỉnh cho món ăn (size, topping...).
class FoodOption {
  final String id;
  final FoodOptionType type;
  final String name;
  final double extraPrice;

  const FoodOption({
    required this.id,
    required this.type,
    required this.name,
    this.extraPrice = 0,
  });
}
