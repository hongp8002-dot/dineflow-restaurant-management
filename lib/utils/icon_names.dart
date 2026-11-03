import 'package:flutter/material.dart';

/// Các tên icon dùng được cho món ăn / danh mục (cột `icon` trong database và trong foods.json).
/// Dùng `const` để Flutter vẫn loại bỏ được các icon không dùng khi build.
const Map<String, IconData> kIconsByName = {
  'coffee': Icons.coffee,
  'local_cafe': Icons.local_cafe,
  'emoji_food_beverage': Icons.emoji_food_beverage,
  'local_bar': Icons.local_bar,
  'rice_bowl': Icons.rice_bowl,
  'dinner_dining': Icons.dinner_dining,
  'ramen_dining': Icons.ramen_dining,
  'lunch_dining': Icons.lunch_dining,
  'local_pizza': Icons.local_pizza,
  'tapas': Icons.tapas,
  'icecream': Icons.icecream,
  'cake': Icons.cake,
  'bakery_dining': Icons.bakery_dining,
  'restaurant': Icons.restaurant,
};

/// Tên icon -> [IconData]; tên lạ hoặc rỗng thì dùng [fallback].
IconData iconFromName(String? name, {IconData fallback = Icons.restaurant_menu}) =>
    kIconsByName[name] ?? fallback;

/// Màu hex `#RRGGBB` (hoặc `RRGGBB`) -> [Color]; sai định dạng thì dùng [fallback].
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF8B5A2B)}) {
  final value = hex?.replaceFirst('#', '').trim();
  if (value == null || value.length != 6) return fallback;
  final parsed = int.tryParse('FF$value', radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
