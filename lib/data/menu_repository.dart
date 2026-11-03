import '../core/api/api_client.dart';
import '../models/food.dart';
import '../models/food_category.dart';

/// Thực đơn (danh mục + món ăn kèm size/topping) lấy từ API.
class MenuRepository {
  MenuRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static MenuRepository instance = MenuRepository();

  final ApiClient _api;

  Future<({List<FoodCategory> categories, List<Food> foods})> fetch() async {
    // Hai request độc lập nên gọi song song cho nhanh.
    final responses = await Future.wait([_api.get('/categories'), _api.get('/foods')]);

    return (
      categories: [for (final c in responses[0].list) FoodCategory.fromApiJson(c)],
      foods: [for (final f in responses[1].list) Food.fromApiJson(f)],
    );
  }
}
