import '../core/api/api_client.dart';
import '../models/food.dart';
import '../models/food_category.dart';
import '../models/promotion.dart';
import '../models/table_model.dart';
import '../models/user.dart';

/// Repository cho Admin: CRUD tài khoản, món ăn, bàn, khuyến mãi.
class AdminRepository {
  AdminRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;
  static final AdminRepository instance = AdminRepository();
  final ApiClient _api;

  // USERS
  Future<List<User>> fetchUsers({String? role, String? status, String? search}) async {
    final res = await _api.get('/admin/users', query: {
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return [for (final u in res.list) User.fromApiJson(u)];
  }
  Future<User> createUser({required String name, required String email, String? phone, required UserRole role}) async {
    final res = await _api.post('/admin/users', body: {'name': name, 'email': email, if (phone != null && phone.isNotEmpty) 'phone': phone, 'role': _roleValue(role)});
    return User.fromApiJson(res.map);
  }
  Future<User> updateUser(String id, {String? name, String? email, String? phone, UserRole? role}) async {
    final res = await _api.put('/admin/users/$id', body: {if (name != null) 'name': name, if (email != null) 'email': email, if (phone != null) 'phone': phone, if (role != null) 'role': _roleValue(role)});
    return User.fromApiJson(res.map);
  }
  Future<User> toggleUserStatus(String id) async {
    final res = await _api.patch('/admin/users/$id/toggle-status', body: {});
    return User.fromApiJson(res.map);
  }
  Future<void> deleteUser(String id) async => _api.delete('/admin/users/$id');

  // FOODS
  Future<List<Food>> fetchFoods({int? categoryId, String? search}) async {
    final res = await _api.get('/admin/foods', query: {if (categoryId != null) 'category_id': categoryId.toString(), if (search != null && search.isNotEmpty) 'search': search});
    return [for (final f in res.list) Food.fromApiJson(f)];
  }
  Future<Food> createFood({required int categoryId, required String name, required double price, String? description, String? imageUrl, bool isAvailable = true, bool isBestSeller = false}) async {
    final res = await _api.post('/admin/foods', body: {'category_id': categoryId, 'name': name, 'price': price, if (description != null && description.isNotEmpty) 'description': description, if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl, 'is_available': isAvailable, 'is_best_seller': isBestSeller});
    return Food.fromApiJson(res.map);
  }
  Future<Food> updateFood(String id, {int? categoryId, String? name, double? price, String? description, String? imageUrl, bool? isAvailable, bool? isBestSeller}) async {
    final res = await _api.put('/admin/foods/$id', body: {if (categoryId != null) 'category_id': categoryId, if (name != null) 'name': name, if (price != null) 'price': price, if (description != null) 'description': description, if (imageUrl != null) 'image_url': imageUrl, if (isAvailable != null) 'is_available': isAvailable, if (isBestSeller != null) 'is_best_seller': isBestSeller});
    return Food.fromApiJson(res.map);
  }
  Future<Food> toggleFoodAvailable(String id) async {
    final res = await _api.patch('/admin/foods/$id/toggle-available', body: {});
    return Food.fromApiJson(res.map);
  }
  /// Xóa vĩnh viễn một món ăn. Gọi DELETE /admin/foods/{id}.
  Future<void> deleteFood(String id) async => _api.delete('/admin/foods/$id');

  // CATEGORIES
  Future<List<FoodCategory>> fetchCategories() async {
    final res = await _api.get('/admin/categories');
    return [for (final c in res.list) FoodCategory.fromApiJson(c)];
  }
  Future<FoodCategory> createCategory({required String name, String? icon, int? sortOrder}) async {
    final res = await _api.post('/admin/categories', body: {'name': name, if (icon != null && icon.isNotEmpty) 'icon': icon, if (sortOrder != null) 'sort_order': sortOrder});
    return FoodCategory.fromApiJson(res.map);
  }
  Future<FoodCategory> updateCategory(String id, {String? name, String? icon, int? sortOrder}) async {
    final res = await _api.put('/admin/categories/$id', body: {if (name != null) 'name': name, if (icon != null) 'icon': icon, if (sortOrder != null) 'sort_order': sortOrder});
    return FoodCategory.fromApiJson(res.map);
  }
  Future<void> deleteCategory(String id) async => _api.delete('/admin/categories/$id');

  // TABLES
  Future<List<TableModel>> fetchTables({String? area}) async {
    final res = await _api.get('/admin/tables', query: {if (area != null) 'area': area});
    return [for (final t in res.list) TableModel.fromApiJson(t)];
  }
  Future<TableModel> createTable({required String number, required String area, required int capacity}) async {
    final res = await _api.post('/admin/tables', body: {'number': number, 'area': area, 'capacity': capacity});
    return TableModel.fromApiJson(res.map);
  }
  Future<TableModel> updateTable(String id, {String? number, String? area, int? capacity}) async {
    final res = await _api.put('/admin/tables/$id', body: {if (number != null) 'number': number, if (area != null) 'area': area, if (capacity != null) 'capacity': capacity});
    return TableModel.fromApiJson(res.map);
  }
  Future<TableModel> toggleTableLocked(String id) async {
    final res = await _api.patch('/admin/tables/$id/toggle-locked', body: {});
    return TableModel.fromApiJson(res.map);
  }
  Future<TableModel> toggleTableActive(String id) async {
    final res = await _api.patch('/admin/tables/$id/toggle-active', body: {});
    return TableModel.fromApiJson(res.map);
  }

  // PROMOTIONS
  Future<List<Promotion>> fetchPromotions() async {
    final res = await _api.get('/admin/promotions');
    return [for (final p in res.list) Promotion.fromApiJson(p)];
  }
  Future<Promotion> createPromotion({required String code, required String title, String? description, required int discountPercent, double? maxDiscount, double? minOrderAmount, required DateTime validFrom, required DateTime validTo, bool isActive = true}) async {
    final res = await _api.post('/admin/promotions', body: {'code': code.toUpperCase(), 'title': title, if (description != null && description.isNotEmpty) 'description': description, 'discount_percent': discountPercent, if (maxDiscount != null) 'max_discount': maxDiscount, if (minOrderAmount != null) 'min_order_amount': minOrderAmount, 'valid_from': validFrom.toIso8601String(), 'valid_to': validTo.toIso8601String(), 'is_active': isActive});
    return Promotion.fromApiJson(res.map);
  }
  Future<Promotion> updatePromotion(String id, {String? title, String? description, int? discountPercent, double? maxDiscount, double? minOrderAmount, DateTime? validFrom, DateTime? validTo}) async {
    final res = await _api.put('/admin/promotions/$id', body: {if (title != null) 'title': title, if (description != null) 'description': description, if (discountPercent != null) 'discount_percent': discountPercent, if (maxDiscount != null) 'max_discount': maxDiscount, if (minOrderAmount != null) 'min_order_amount': minOrderAmount, if (validFrom != null) 'valid_from': validFrom.toIso8601String(), if (validTo != null) 'valid_to': validTo.toIso8601String()});
    return Promotion.fromApiJson(res.map);
  }
  Future<Promotion> togglePromotionActive(String id) async {
    final res = await _api.patch('/admin/promotions/$id/toggle-active', body: {});
    return Promotion.fromApiJson(res.map);
  }

  String _roleValue(UserRole role) => switch (role) {
    UserRole.orderStaff => 'order_staff',
    UserRole.cashier => 'cashier',
    UserRole.admin => 'admin',
    UserRole.customer => 'customer',
  };
}
