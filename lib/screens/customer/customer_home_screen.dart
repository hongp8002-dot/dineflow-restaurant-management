import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/cart_store.dart';
import '../../data/mock_data.dart';
import '../../models/food.dart';
import '../../models/reservation.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/food_card.dart';
import '../../widgets/section_header.dart';
import 'customer_order_actions.dart';
import 'customer_shell.dart';

const EdgeInsets _pagePadding = EdgeInsets.symmetric(horizontal: 20);

/// Tab Trang chủ của Khách hàng, dựng theo mockup "Trang chủ":
/// lời chào → ô tìm kiếm → thẻ lịch đặt bàn sắp tới (kèm nút Đặt bàn ngay)
/// → chip danh mục → lưới "Món nổi bật".
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  /// Danh mục đang lọc lưới món; null = "Tất cả".
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    // Thẻ lịch đặt bàn sắp tới cập nhật khi khách đặt hoặc huỷ bàn ở tab khác.
    MockData.reservationsVersion.addListener(_onReservationsChanged);
  }

  @override
  void dispose() {
    MockData.reservationsVersion.removeListener(_onReservationsChanged);
    super.dispose();
  }

  void _onReservationsChanged() => setState(() {});

  /// Chuyển sang tab khác trong khung Khách hàng; nếu màn hình đang được mở
  /// riêng (không nằm trong khung) thì mở route tương ứng.
  void _goTo(CustomerTab tab, String fallbackRoute) {
    if (!CustomerShell.goTo(context, tab)) {
      Navigator.of(context).pushNamed(fallbackRoute);
    }
  }

  List<Food> get _featuredFoods {
    if (_categoryId == null) return MockData.foods.take(6).toList();
    return MockData.foods.where((f) => f.categoryId == _categoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = MockData.currentCustomerUser;
    final upcoming = MockData.upcomingReservations.isNotEmpty ? MockData.upcomingReservations.first : null;
    final foods = _featuredFoods;

    // Các khối xuất hiện lần lượt khi mở màn hình.
    var order = 0;
    Widget step(Widget child) => FadeSlideIn.staggered(index: order++, child: child);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 24, bottom: 28),
          children: [
            step(Padding(padding: _pagePadding, child: _Greeting(name: user.name))),
            const SizedBox(height: 22),
            step(Padding(
              padding: _pagePadding,
              child: _SearchBox(onTap: () => _goTo(CustomerTab.menu, AppRoutes.customerMenu)),
            )),
            const SizedBox(height: 20),
            step(Padding(
              padding: _pagePadding,
              child: _BookingCard(
                reservation: upcoming,
                onOpenBookings: () => _goTo(CustomerTab.bookings, AppRoutes.customerMyBookings),
                onBookNow: () => _goTo(CustomerTab.booking, AppRoutes.customerBooking),
              ),
            )),
            const SizedBox(height: 26),
            step(const Padding(padding: _pagePadding, child: SectionHeader(title: 'Danh mục'))),
            const SizedBox(height: 12),
            step(_CategoryPills(
              selectedId: _categoryId,
              onSelected: (id) => setState(() => _categoryId = id),
            )),
            const SizedBox(height: 26),
            step(Padding(
              padding: _pagePadding,
              child: SectionHeader(
                title: 'Món nổi bật',
                actionLabel: 'Xem tất cả',
                onAction: () => _goTo(CustomerTab.menu, AppRoutes.customerMenu),
              ),
            )),
            const SizedBox(height: 14),
            Padding(
              padding: _pagePadding,
              child: AnimatedSwitcher(
                duration: AppMotion.normal,
                child: foods.isEmpty
                    ? Padding(
                        key: const ValueKey('no-food'),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Danh mục này chưa có món',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                        ),
                      )
                    : GridView.builder(
                        key: ValueKey(_categoryId),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 22,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.74,
                        ),
                        itemCount: foods.length,
                        itemBuilder: (context, index) {
                          final food = foods[index];
                          return FadeSlideIn.staggered(
                            index: index,
                            offsetY: 12,
                            child: FoodCard(
                              food: food,
                              onTap: () => Navigator.of(context)
                                  .pushNamed(AppRoutes.customerFoodDetail, arguments: food.id),
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

/// "Xin chào," + tên khách in đậm lớn, nút chuông tròn nền kem bên phải.
class _Greeting extends StatelessWidget {
  final String name;

  const _Greeting({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xin chào,', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        PressScale(
          onTap: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Chưa có thông báo mới'))),
          scale: 0.9,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
            child: Icon(Icons.notifications_none_rounded, size: 24, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// Ô tìm kiếm nền kem, không viền. Chạm vào sẽ mở tab Thực đơn để tìm.
class _SearchBox extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBox({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tìm món, đồ uống...',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ vàng nhạt: lịch đặt bàn sắp tới (nếu có) và nút "Đặt bàn ngay".
class _BookingCard extends StatelessWidget {
  final Reservation? reservation;
  final VoidCallback onOpenBookings;
  final VoidCallback onBookNow;

  const _BookingCard({
    required this.reservation,
    required this.onOpenBookings,
    required this.onBookNow,
  });

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r != null ? 'LỊCH ĐẶT BÀN SẮP TỚI' : 'ĐẶT BÀN TRƯỚC',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r != null
                          ? '${AppFormatters.time(r.dateTime)} · ${AppFormatters.weekdayDate(r.dateTime)}'
                          : 'Giữ chỗ trước khi đến',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      r != null
                          ? '${r.tableNumber} · ${r.area} · ${r.guestCount} khách'
                          : 'Chọn giờ, số khách và bàn bạn thích',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (r != null) ...[
                const SizedBox(width: 10),
                PressScale(
                  onTap: onOpenBookings,
                  scale: 0.88,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                    child: Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          PressScale(
            onTap: onBookNow,
            scale: 0.98,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.textOnPrimary),
                  const SizedBox(width: 10),
                  Text(
                    'Đặt bàn ngay',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textOnPrimary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hàng chip danh mục dạng viên thuốc: chip đang chọn nền nâu đen chữ trắng.
class _CategoryPills extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _CategoryPills({required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final entries = <(String?, String)>[
      (null, 'Tất cả'),
      ...MockData.categories.map((c) => (c.id, c.name)),
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: _pagePadding,
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final (id, label) = entries[index];
          final selected = id == selectedId;
          return PressScale(
            onTap: () => onSelected(id),
            scale: 0.94,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: Curves.easeOut,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: selected ? AppColors.ink : AppColors.border, width: 1.4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.textOnDark : AppColors.textPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
