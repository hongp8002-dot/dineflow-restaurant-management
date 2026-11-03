import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/cart_store.dart';
import '../../data/mock_data.dart';
import '../../models/food.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/food_image.dart';
import '../../widgets/quantity_stepper.dart';
import 'booking_checkout.dart';
import 'customer_order_actions.dart';

/// Bước 2 của luồng đặt bàn qua app: "Đặt món trước".
///
/// Khách chọn món để nhà hàng chuẩn bị sẵn, hoặc bỏ qua để gọi món khi đến
/// quán. Bàn đang được giữ nên có đồng hồ đếm ngược; thoát khỏi màn hình này
/// (quay lại) sẽ huỷ lượt đặt bàn sau khi khách xác nhận.
class PreOrderScreen extends StatefulWidget {
  const PreOrderScreen({super.key});

  @override
  State<PreOrderScreen> createState() => _PreOrderScreenState();
}

class _PreOrderScreenState extends State<PreOrderScreen> with BookingHoldTimer {
  String? _categoryId;

  /// Đang lọc chip "Đã chọn": chỉ hiện các món khách đã chọn.
  bool _showPicked = false;

  /// Id các món hiện trong chip "Đã chọn", chốt lúc bấm chip. Giảm một món
  /// về 0 thì món vẫn ở lại danh sách (hiện nút +) cho tới khi đổi chip, để
  /// món không biến mất đột ngột và khách lỡ tay vẫn thêm lại được.
  Set<String> _pickedIds = {};

  CartStore get _order => BookingCheckout.instance.preOrder;

  @override
  void initState() {
    super.initState();
    _order.addListener(_onOrderChanged);
    // Vào bước này mà đã có món (chọn từ Thực đơn, hoặc "Đặt lại" đơn cũ)
    // thì mở sẵn chip "Đã chọn" để khách xem lại nhanh.
    if (!_order.isEmpty) _selectPicked();
  }

  @override
  void dispose() {
    _order.removeListener(_onOrderChanged);
    super.dispose();
  }

  void _onOrderChanged() => setState(() {});

  void _selectPicked() {
    _showPicked = true;
    _categoryId = null;
    _pickedIds = {for (final item in _order.items) item.foodId};
  }

  void _selectCategory(String? categoryId) {
    setState(() {
      _showPicked = false;
      _categoryId = categoryId;
    });
  }

  List<Food> get _foods => MockData.foods
      .where((f) => f.isAvailable)
      .where((f) => _showPicked
          ? _pickedIds.contains(f.id)
          : (_categoryId == null || f.categoryId == _categoryId))
      .toList();

  int _quantityOf(Food food) =>
      _order.items.where((i) => i.foodId == food.id).fold(0, (sum, i) => sum + i.quantity);

  /// Đổi số lượng của món trong danh sách đặt trước (gộp về một dòng cho mỗi món).
  void _setQuantity(Food food, int quantity) {
    final lines = _order.items.where((i) => i.foodId == food.id).toList();
    if (lines.isEmpty) {
      if (quantity > 0) addOneFood(_order, food);
      return;
    }
    _order.updateQuantity(lines.first.id, quantity);
  }

  Future<void> _confirmAbandon() async {
    final checkout = BookingCheckout.instance;
    final reservation = checkout.reservation;
    if (reservation == null || !checkout.isActive) {
      Navigator.of(context).pop();
      return;
    }
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ đặt bàn?'),
        content: Text(
          '${reservation.tableNumber} đang được giữ cho bạn. Thoát lúc này sẽ huỷ lượt đặt bàn '
          'và nhường bàn cho khách khác.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ở lại')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Huỷ đặt bàn', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (leave != true) return;
    checkout.release();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final checkout = BookingCheckout.instance;
    final reservation = checkout.reservation;

    if (reservation == null || !checkout.isActive) {
      return const Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AppPageHeader(title: 'Đặt món trước', showBack: true),
              ),
              Expanded(
                child: EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'Không có lượt đặt bàn đang giữ',
                  message: 'Hãy đặt bàn trước, sau đó bạn có thể đặt món trước tại đây',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final foods = _foods;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmAbandon();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AppPageHeader(
                  title: 'Đặt món trước',
                  subtitle: '${reservation.tableNumber} · ${AppFormatters.time(reservation.dateTime)} · '
                      '${AppFormatters.weekdayDate(reservation.dateTime)}',
                  showBack: true,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: CheckoutSteps(current: 1),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: HoldCountdownBanner(remaining: checkout.remaining),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Chip "Đã chọn" chỉ hiện khi đã có món (hoặc đang mở chip này).
                    if (!_order.isEmpty || _showPicked)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CategoryChip(
                          label: 'Đã chọn (${_order.totalQuantity})',
                          icon: Icons.check_circle_rounded,
                          selected: _showPicked,
                          onTap: () => setState(_selectPicked),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        label: 'Tất cả',
                        selected: !_showPicked && _categoryId == null,
                        onTap: () => _selectCategory(null),
                      ),
                    ),
                    for (final c in MockData.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CategoryChip(
                          label: c.name,
                          selected: !_showPicked && _categoryId == c.id,
                          onTap: () => _selectCategory(c.id),
                        ),
                      ),
                  ],
                ),
              ),
              if (_showPicked)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Text(
                    'Món bạn đã chọn · Bấm "Tất cả" để thêm món khác',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  itemCount: foods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final food = foods[index];
                    return FadeSlideIn.staggered(
                      index: index,
                      offsetY: 10,
                      child: _PreOrderFoodRow(
                        food: food,
                        quantity: _quantityOf(food),
                        onAdd: () => addOneFood(_order, food),
                        onChanged: (q) => _setQuantity(food, q),
                      ),
                    );
                  },
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final empty = _order.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
                Text(
                  empty ? 'Chưa chọn món' : 'Đã chọn ${_order.totalQuantity} món',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                AnimatedValueText(
                  AppFormatters.currency(_order.subtotal),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: AppButton(
              key: const ValueKey('pre-order-next'),
              // Không chọn món vẫn được đi tiếp: bước đặt món trước là tuỳ chọn.
              label: empty ? 'Bỏ qua, thanh toán' : 'Tiếp tục thanh toán',
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.customerBookingPayment),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreOrderFoodRow extends StatelessWidget {
  final Food food;
  final int quantity;
  final VoidCallback onAdd;
  final ValueChanged<int> onChanged;

  const _PreOrderFoodRow({
    required this.food,
    required this.quantity,
    required this.onAdd,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 60, height: 60, child: FoodImage(food: food, borderRadius: 14, iconSize: 24)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(AppFormatters.currency(food.price),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: AppMotion.fast,
          child: quantity == 0
              ? PressScale(
                  key: const ValueKey('add'),
                  onTap: onAdd,
                  scale: 0.85,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: Icon(Icons.add_rounded, size: 22, color: AppColors.textPrimary),
                  ),
                )
              : QuantityStepper(
                  key: const ValueKey('stepper'),
                  value: quantity,
                  min: 0,
                  onChanged: onChanged,
                ),
        ),
      ],
    );
  }
}