import 'package:flutter/material.dart';

import '../core/api/api_config.dart';
import '../utils/icon_names.dart';
import 'food_option.dart';

/// Món ăn / thức uống trong thực đơn.
class Food {
  final String id;
  final String categoryId;
  final String name;
  final double price;
  final String description;

  /// Đường dẫn asset (`assets/images/foods/...`) hoặc link `http(s)://...`;
  /// null thì hiện [icon] thay ảnh.
  final String? image;
  final IconData icon;
  final Color color;
  final double rating;
  final bool isBestSeller;
  final bool isAvailable;
  final List<FoodOption> options;

  const Food({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.price,
    this.description = '',
    this.image,
    required this.icon,
    required this.color,
    this.rating = 4.5,
    this.isBestSeller = false,
    this.isAvailable = true,
    this.options = const [],
  });

  /// Đọc một món trong `assets/data/foods.json`.
  ///
  /// `options` trong JSON là tên nhóm tùy chọn (`"size"`, `"topping"`), được
  /// đổi thành danh sách [FoodOption] qua [optionGroups].
  factory Food.fromJson(Map<String, dynamic> json, Map<String, List<FoodOption>> optionGroups) {
    final image = (json['image'] as String?)?.trim();
    final color = (json['color'] as String?)?.replaceFirst('#', '');
    return Food(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      image: (image == null || image.isEmpty) ? null : image,
      icon: iconFromName(json['icon'] as String?),
      color: color == null ? const Color(0xFF8B5A2B) : Color(int.parse('FF$color', radix: 16)),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      isBestSeller: json['isBestSeller'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? true,
      options: [
        for (final group in (json['options'] as List<dynamic>? ?? const [])) ...?optionGroups[group],
      ],
    );
  }

  /// Đọc một món do API `/foods` trả về (khóa `snake_case`).
  ///
  /// Mỗi món ở server có tùy chọn (size/topping) riêng nên [options] lấy thẳng từ món đó;
  /// id của chúng là id thật trên server, dùng để gửi `option_ids` khi đặt món.
  factory Food.fromApiJson(Map<String, dynamic> json) {
    final image = (json['image'] as String?)?.trim();
    return Food(
      id: json['id'].toString(),
      categoryId: json['category_id'].toString(),
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      description: json['description'] as String? ?? '',
      image: (image == null || image.isEmpty) ? null : ApiConfig.resolveMediaUrl(image),
      icon: iconFromName(json['icon'] as String?),
      color: colorFromHex(json['color'] as String?),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      isBestSeller: json['is_best_seller'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      options: [
        for (final o in (json['options'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          FoodOption(
            id: o['id'].toString(),
            type: o['group'] == 'topping' ? FoodOptionType.topping : FoodOptionType.size,
            name: o['name'] as String,
            extraPrice: (o['price_modifier'] as num?)?.toDouble() ?? 0,
          ),
      ],
    );
  }

  List<FoodOption> get sizes => options.where((o) => o.type == FoodOptionType.size).toList();

  List<FoodOption> get toppings => options.where((o) => o.type == FoodOptionType.topping).toList();
}
