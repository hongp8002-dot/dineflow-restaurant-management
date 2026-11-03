import 'package:flutter/material.dart';

import '../../data/cart_store.dart';
import '../../data/mock_data.dart';
import '../../data/favorite_store.dart';
import '../../models/food.dart';
import '../../models/food_option.dart';
import '../../models/order_item.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/food_image.dart';
import '../../widgets/quantity_stepper.dart';

/// Màn hình chi tiết món: chọn size, topping, số lượng, ghi chú.
/// Ảnh món dùng Hero nối tiếp từ thực đơn, tổng tiền đổi số có hiệu ứng trượt.
class FoodDetailScreen extends StatefulWidget {
  final String foodId;
  const FoodDetailScreen({super.key, required this.foodId});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  FoodOption? _selectedSize;
  final Set<String> _selectedToppingIds = {};
  int _quantity = 1;
  final _noteController = TextEditingController();

  late final Food _food = MockData.foodById(widget.foodId);

  @override
  void initState() {
    super.initState();
    if (_food.sizes.isNotEmpty) _selectedSize = _food.sizes.first;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<FoodOption> get _selectedOptions {
    final options = <FoodOption>[];
    if (_selectedSize != null) options.add(_selectedSize!);
    options.addAll(_food.toppings.where((t) => _selectedToppingIds.contains(t.id)));
    return options;
  }

  double get _unitPrice => _food.price + _selectedOptions.fold(0.0, (sum, o) => sum + o.extraPrice);

  double get _totalPrice => _unitPrice * _quantity;

  /// Chọn món (kèm size/topping/ghi chú) để đặt trước khi đặt bàn. Món hiện ở
  /// thanh "món đã chọn" của Trang chủ / Thực đơn nên không cần báo thêm.
  void _pickFood() {
    AppCart.customer.addItem(OrderItem(
      id: '${_food.id}-${DateTime.now().millisecondsSinceEpoch}',
      foodId: _food.id,
      foodName: _food.name,
      price: _food.price,
      quantity: _quantity,
      selectedOptions: _selectedOptions,
      note: _noteController.text.trim(),
    ));
    Navigator.of(context).pop();
  }

  void _toggleFavorite(BuildContext context) {
    final liked = FavoriteStore.instance.toggle(_food.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(liked ? 'Đã thêm vào Món yêu thích' : 'Đã bỏ khỏi Món yêu thích'),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(context),
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        step(_buildTitle(context)),
                        step(Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _food.description.isEmpty ? 'Món ăn hấp dẫn tại DineFlow.' : _food.description,
                            style: TextStyle(color: AppColors.textSecondary, height: 1.55, fontSize: 13.5),
                          ),
                        )),
                        if (_food.sizes.isNotEmpty) step(_buildSizes()),
                        if (_food.toppings.isNotEmpty) step(_buildToppings()),
                        step(_buildQuantity()),
                        step(_buildNote()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        Hero(
          tag: 'food-${_food.id}',
          child: SizedBox(
            height: 280,
            width: double.infinity,
            child: FoodImage(food: _food, borderRadius: 0, iconSize: 96),
          ),
        ),
        Positioned(
          top: 8,
          left: 16,
          right: 16,
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                // Nút ♡: bấm để thêm/bỏ món khỏi danh sách yêu thích.
                ListenableBuilder(
                  listenable: FavoriteStore.instance,
                  builder: (context, _) {
                    final liked = FavoriteStore.instance.isFavorite(_food.id);
                    return _CircleIconButton(
                      icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: liked ? const Color(0xFFE53935) : null,
                      onTap: () => _toggleFavorite(context),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (_food.isBestSeller)
          Positioned(
            left: 20,
            bottom: 38,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.goldShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.textOnPrimary),
                  const SizedBox(width: 4),
                  Text('Món bán chạy',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textOnPrimary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(_food.name, style: Theme.of(context).textTheme.headlineSmall)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: AppColors.primaryDark, size: 16),
                  const SizedBox(width: 3),
                  Text('${_food.rating}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          AppFormatters.currency(_food.price),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildSizes() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Chọn size'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _food.sizes.map((size) {
              final selected = _selectedSize?.id == size.id;
              return _SelectableChip(
                label: size.extraPrice > 0
                    ? '${size.name} (+${AppFormatters.currency(size.extraPrice)})'
                    : size.name,
                selected: selected,
                onTap: () => setState(() => _selectedSize = size),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToppings() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Chọn topping'),
          const SizedBox(height: 10),
          // Material (không dùng Container có màu nền) để CheckboxListTile vẽ được
          // hiệu ứng chạm; Container có màu nền sẽ che mất và Flutter báo lỗi.
          Material(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Column(
                children: _food.toppings.map((topping) {
                  final checked = _selectedToppingIds.contains(topping.id);
                  return CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    value: checked,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                    checkColor: AppColors.textOnPrimary,
                    title: Text(topping.name,
                        style:
                            TextStyle(fontSize: 14, fontWeight: checked ? FontWeight.w700 : FontWeight.w500)),
                    secondary: Text('+${AppFormatters.currency(topping.extraPrice)}',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedToppingIds.add(topping.id);
                        } else {
                          _selectedToppingIds.remove(topping.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantity() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant_outlined, size: 21, color: AppColors.textPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Số lượng',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                ),
                QuantityStepper(
                  value: _quantity,
                  size: QuantityStepperSize.large,
                  buttonColor: AppColors.surface,
                  onChanged: (q) => setState(() => _quantity = q.clamp(1, 99)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Ghi chú'),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Vd: Ít đường, không đá...'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Tổng tiền', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  AnimatedValueText(
                    AppFormatters.currency(_totalPrice),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppButton(
                label: _food.isAvailable ? 'Chọn món' : 'Hết món',
                icon: _food.isAvailable ? Icons.add_rounded : null,
                onPressed: _food.isAvailable ? _pickFood : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary));
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// Màu icon; null = màu chữ chính.
  final Color? color;

  const _CircleIconButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.88,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: AppColors.softShadow,
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.fast,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Icon(icon, key: ValueKey(icon), size: 19, color: color ?? AppColors.textPrimary),
        ),
      ),
    );
  }
}