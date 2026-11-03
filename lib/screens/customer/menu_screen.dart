import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/cart_store.dart';
import '../../data/mock_data.dart';
import '../../models/food.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/food_card.dart';
import 'customer_order_actions.dart';

enum _MenuSort { none, priceAsc, priceDesc }

String _sortLabel(_MenuSort sort) => switch (sort) {
      _MenuSort.none => 'Mặc định',
      _MenuSort.priceAsc => 'Giá thấp đến cao',
      _MenuSort.priceDesc => 'Giá cao đến thấp',
    };

/// Tab Thực đơn: tìm kiếm, lọc theo danh mục, hiển thị món dạng Grid.
/// Nút "+" chọn món để đặt trước khi đặt bàn (xem [PickedFoodsBar]).
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String? _selectedCategoryId;
  String _keyword = '';
  _MenuSort _sort = _MenuSort.none;

  List<Food> get _filteredFoods {
    final foods = MockData.foods.where((food) {
      final matchesCategory = _selectedCategoryId == null || food.categoryId == _selectedCategoryId;
      final matchesKeyword =
          _keyword.trim().isEmpty || food.name.toLowerCase().contains(_keyword.trim().toLowerCase());
      return matchesCategory && matchesKeyword;
    }).toList();

    switch (_sort) {
      case _MenuSort.priceAsc:
        foods.sort((a, b) => a.price.compareTo(b.price));
      case _MenuSort.priceDesc:
        foods.sort((a, b) => b.price.compareTo(a.price));
      case _MenuSort.none:
        break;
    }
    return foods;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sắp xếp theo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 12),
                ..._MenuSort.values.map((option) {
                  final selected = option == _sort;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PressScale(
                      onTap: () {
                        setState(() => _sort = option);
                        Navigator.pop(context);
                      },
                      scale: 0.98,
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primaryLight : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _sortLabel(option),
                                style: TextStyle(
                                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (selected)
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: Icon(Icons.check_rounded, size: 14, color: AppColors.textOnPrimary),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final foods = _filteredFoods;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: AppPageHeader(title: 'Thực đơn', subtitle: 'Chọn món để đặt trước khi đặt bàn'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: AppSearchBar(
                onChanged: (v) => setState(() => _keyword = v),
                onFilterTap: _showFilterSheet,
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      label: 'Tất cả',
                      selected: _selectedCategoryId == null,
                      onTap: () => setState(() => _selectedCategoryId = null),
                    ),
                  ),
                  ...MockData.categories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        label: category.name,
                        icon: category.icon,
                        selected: _selectedCategoryId == category.id,
                        onTap: () => setState(() => _selectedCategoryId = category.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Thẻ "Sắp xếp: ..." trượt xuống khi có bộ lọc, thu lại khi bỏ lọc.
            AnimatedSize(
              duration: AppMotion.normal,
              curve: Curves.easeOutCubic,
              child: _sort == _MenuSort.none
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: PressScale(
                          onTap: () => setState(() => _sort = _MenuSort.none),
                          scale: 0.94,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primarySoft),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Sắp xếp: ${_sortLabel(_sort)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.close_rounded, size: 14, color: AppColors.textPrimary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                child: foods.isEmpty
                    ? const EmptyState(
                        key: ValueKey('empty'),
                        icon: Icons.search_off_rounded,
                        title: 'Không tìm thấy món ăn',
                        message: 'Thử tìm với từ khóa hoặc danh mục khác',
                      )
                    : GridView.builder(
                        key: ValueKey('${_selectedCategoryId}_$_sort'),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: foods.length,
                        itemBuilder: (context, index) {
                          final food = foods[index];
                          return FadeSlideIn.staggered(
                            index: index,
                            child: FoodCard(
                              food: food,
                              heroTag: 'food-${food.id}',
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.customerFoodDetail, arguments: food.id),
                              // Chọn món để đặt trước khi đặt bàn (hiện ở thanh món đã chọn phía dưới).
                              onAdd: () => addOneFood(AppCart.customer, food),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
