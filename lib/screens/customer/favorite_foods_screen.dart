import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/mock_data.dart';
import '../../data/favorite_store.dart';
import '../../models/food.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/food_card.dart';
import 'customer_shell.dart';

/// Màn "Món yêu thích": lưới các món khách đã bấm ♡ ở màn chi tiết món.
class FavoriteFoodsScreen extends StatelessWidget {
  const FavoriteFoodsScreen({super.key});

  /// Số cột theo bề ngang: điện thoại 2 cột, màn rộng nhiều cột hơn.
  static int _columns(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  /// Màn này mở chồng lên khung Khách hàng (không nằm trong khung), nên mở
  /// lại khung ở tab Thực đơn thay vì gọi [CustomerShell.goTo].
  void _openMenu(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.customerHome,
      (route) => false,
      arguments: CustomerTab.menu,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = FavoriteStore.instance;

    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            // Chỉ lấy các id còn tồn tại trong thực đơn.
            final foods = <Food>[
              for (final id in store.foodIds)
                ...MockData.foods.where((f) => f.id == id),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: AppPageHeader(
                    title: 'Món yêu thích',
                    subtitle: foods.isEmpty ? null : '${foods.length} món',
                  ),
                ),
                Expanded(
                  child: foods.isEmpty
                      ? EmptyState(
                          icon: Icons.favorite_border_rounded,
                          title: 'Chưa có món yêu thích',
                          message: 'Bấm biểu tượng ♡ ở trang chi tiết món\nđể lưu món bạn thích vào đây.',
                          action: AppButton(
                            label: 'Xem thực đơn',
                            fullWidth: false,
                            onPressed: () => _openMenu(context),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) => GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                            itemCount: foods.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _columns(constraints.maxWidth),
                              mainAxisSpacing: 18,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.74,
                            ),
                            itemBuilder: (context, i) {
                              final food = foods[i];
                              return FadeSlideIn.staggered(
                                index: i,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: FoodCard(
                                        food: food,
                                        onTap: () => Navigator.of(context)
                                            .pushNamed(AppRoutes.customerFoodDetail, arguments: food.id),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: _UnfavoriteButton(onTap: () => store.remove(food.id)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Nút ♥ đỏ góc ảnh món; bấm để bỏ yêu thích ngay trong lưới.
class _UnfavoriteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _UnfavoriteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Bỏ yêu thích',
      child: PressScale(
        onTap: onTap,
        scale: 0.85,
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(Icons.favorite_rounded, size: 18, color: Color(0xFFE53935)),
        ),
      ),
    );
  }
}
