import 'dart:convert';

import 'package:dineflow/core/api/api_client.dart';
import 'package:dineflow/core/api/api_config.dart';
import 'package:dineflow/core/session/session_store.dart';
import 'package:dineflow/data/app_data.dart';
import 'package:dineflow/data/menu_repository.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/models/food.dart';
import 'package:dineflow/models/food_category.dart';
import 'package:dineflow/models/food_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _foodJson = {
  'id': 4,
  'category_id': 2,
  'name': 'Trà đào cam sả',
  'price': 39000,
  'description': null,
  'image': 'http://127.0.0.1:8000/storage/foods/tra_dao_cam_sa.jpg',
  'icon': 'emoji_food_beverage',
  'color': '#E8A22C',
  'rating': 4.7,
  'is_best_seller': true,
  'is_available': false,
  'options': [
    {'id': 10, 'group': 'size', 'name': 'Size M', 'price_modifier': 8000},
    {'id': 13, 'group': 'topping', 'name': 'Trân châu', 'price_modifier': 6000.0},
  ],
};

http.Response _ok(Object data) => http.Response.bytes(
      utf8.encode(jsonEncode({'status': 'success', 'message': 'OK', 'data': data})),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  group('Food.fromApiJson', () {
    test('đọc đủ trường, id thành chuỗi, tùy chọn có id thật của server', () {
      final food = Food.fromApiJson(_foodJson);

      expect(food.id, '4');
      expect(food.categoryId, '2');
      expect(food.name, 'Trà đào cam sả');
      expect(food.price, 39000);
      expect(food.description, '');
      expect(food.icon, Icons.emoji_food_beverage);
      expect(food.color, const Color(0xFFE8A22C));
      expect(food.rating, 4.7);
      expect(food.isBestSeller, isTrue);
      expect(food.isAvailable, isFalse);

      expect(food.sizes.single.id, '10');
      expect(food.sizes.single.extraPrice, 8000);
      expect(food.toppings.single.type, FoodOptionType.topping);
      expect(food.toppings.single.extraPrice, 6000);
    });

    test('món tối giản: không ảnh, không option, màu/icon lạ dùng giá trị mặc định', () {
      final food = Food.fromApiJson({
        'id': 1,
        'category_id': 1,
        'name': 'Espresso',
        'price': 35000,
        'image': '  ',
        'icon': 'khong_co_icon_nay',
        'color': 'khong-phai-mau',
      });

      expect(food.image, isNull);
      expect(food.icon, Icons.restaurant_menu);
      expect(food.color, const Color(0xFF8B5A2B));
      expect(food.options, isEmpty);
      expect(food.isAvailable, isTrue);
    });
  });

  test('FoodCategory.fromApiJson', () {
    final c = FoodCategory.fromApiJson({'id': 3, 'name': 'Nước ép', 'icon': 'local_bar'});
    expect((c.id, c.name, c.icon), ('3', 'Nước ép', Icons.local_bar));
  });

  group('ApiConfig.resolveMediaUrl', () {
    test('đổi địa chỉ local của server dev sang địa chỉ app đang dùng', () {
      final base = Uri.parse(ApiConfig.baseUrl);
      final resolved = Uri.parse(ApiConfig.resolveMediaUrl('http://127.0.0.1:8000/storage/foods/a.jpg?v=2'));

      expect(resolved.host, base.host);
      expect(resolved.port, base.port);
      expect(resolved.path, '/storage/foods/a.jpg');
      expect(resolved.query, 'v=2');
    });

    test('giữ nguyên link ở host khác (CDN) và đường dẫn tương đối', () {
      expect(ApiConfig.resolveMediaUrl('https://cdn.example.com/a.jpg'), 'https://cdn.example.com/a.jpg');
      expect(ApiConfig.resolveMediaUrl('assets/images/foods/a.png'), 'assets/images/foods/a.png');
    });
  });

  group('MenuRepository + AppData', () {
    // flutter_test_config gắn MenuRepository giả cho mọi test; trả lại sau mỗi test.
    late MenuRepository originalMenu;
    late List<FoodCategory> originalCategories;
    late List<Food> originalFoods;

    setUp(() {
      originalMenu = MenuRepository.instance;
      originalCategories = MockData.categories;
      originalFoods = MockData.foods;
    });

    tearDown(() {
      MenuRepository.instance = originalMenu;
      MockData.setMenu(categories: originalCategories, foods: originalFoods);
    });

    MenuRepository repoWith(http.Response Function(http.Request) handler) => MenuRepository(
          api: ApiClient(
              client: MockClient((r) async => handler(r)),
              session: SessionStore(),
              baseUrl: 'http://test/api'),
        );

    test('gọi /categories và /foods, trả về model đã parse', () async {
      final paths = <String>[];
      final repo = repoWith((req) {
        paths.add(req.url.path);
        return req.url.path.endsWith('/categories')
            ? _ok([
                {'id': 2, 'name': 'Trà', 'icon': 'emoji_food_beverage'}
              ])
            : _ok([_foodJson]);
      });

      final menu = await repo.fetch();

      expect(paths, unorderedEquals(['/api/categories', '/api/foods']));
      expect(menu.categories.single.name, 'Trà');
      expect(menu.foods.single.options, hasLength(2));
    });

    test('AppData.load thay thực đơn mẫu bằng thực đơn từ server', () async {
      MenuRepository.instance = repoWith((req) => req.url.path.endsWith('/categories')
          ? _ok([
              {'id': 2, 'name': 'Trà', 'icon': 'emoji_food_beverage'}
            ])
          : _ok([_foodJson]));

      final error = await AppData.load();

      expect(error, isNull);
      expect(MockData.foods.map((f) => f.name), ['Trà đào cam sả']);
      expect(MockData.categories.map((c) => c.id), ['2']);
    });

    test('AppData.load lỗi mạng: trả thông báo và GIỮ nguyên thực đơn đang có', () async {
      MenuRepository.instance = repoWith((_) => throw http.ClientException('offline'));
      final before = MockData.foods;

      final error = await AppData.load();

      expect(error, startsWith('Không tải được thực đơn'));
      expect(MockData.foods, same(before));
    });
  });
}
