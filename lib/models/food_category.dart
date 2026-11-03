import 'package:flutter/material.dart';

import '../utils/icon_names.dart';

/// Danh mục món ăn/thức uống.
class FoodCategory {
  final String id;
  final String name;
  final IconData icon;

  const FoodCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  /// Đọc một danh mục do API `/categories` trả về.
  factory FoodCategory.fromApiJson(Map<String, dynamic> json) {
    return FoodCategory(
      id: json['id'].toString(),
      name: json['name'] as String,
      icon: iconFromName(json['icon'] as String?),
    );
  }
}
