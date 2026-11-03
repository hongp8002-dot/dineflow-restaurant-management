import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_navigator.dart';
import '../../app/routes.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../models/revenue.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/live_data.dart';
import '../../widgets/mock_bar_chart.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

/// Số cột của lưới thống kê theo bề ngang màn hình: điện thoại 2 cột,
/// tablet/nửa cửa sổ desktop 3 cột, cửa sổ đủ rộng hiển thị cả 4 thẻ trên
/// một hàng.
int _statGridColumns(double width) {
  if (width >= 900) return 4;
  if (width >= 600) return 3;
  return 2;
}

/// Số cột của lưới "Quản lý nhanh" (5 mục) theo bề ngang màn hình.
int _quickManageColumns(double width) {
  if (width >= 900) return 5;
  if (width >= 650) return 4;
  return 3;
}

/// Dashboard tổng quan của Admin.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  /// Số liệu lấy từ báo cáo của server, tự tải mới khi mở màn và khi kéo để làm mới.
  @override
  Widget build(BuildContext context) => LiveData(
        sources: const {LiveSource.report},
        builder: _buildContent,
      );

  /// "+12% so với hôm qua" / "-5% so với tuần trước"; null khi kỳ trước không có doanh thu để so.
  static String? _trend(double current, double previous, String versus) {
    final pct = ReportOverview.changePercent(current, previous);
    if (pct == null) return null;
    return '${pct >= 0 ? "+" : ""}$pct% $versus';
  }

  Widget _buildContent(BuildContext context, Future<void> Function() refresh) {
    final report = MockData.report;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard quản trị'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Đăng xuất',
            onPressed: signOut,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              FadeSlideIn(
                child: LayoutBuilder(
                  builder: (context, constraints) => GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // Dùng mainAxisExtent (chiều cao cố định) thay cho childAspectRatio:
                  // chiều cao ô thống kê không còn phụ thuộc bề ngang màn hình nên
                  // nội dung không bị tràn trên máy hẹp. Số cột co giãn theo
                  // constraints.maxWidth để tận dụng cửa sổ desktop rộng.
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _statGridColumns(constraints.maxWidth),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 158,
                  ),
                  children: [
                    StatCard(
                      label: 'Doanh thu hôm nay',
                      value: AppFormatters.currency(report.todayRevenue),
                      icon: Icons.payments_outlined,
                      color: AppColors.success,
                      trend: _trend(report.todayRevenue, report.yesterdayRevenue, 'so với hôm qua'),
                      trendUp: report.todayRevenue >= report.yesterdayRevenue,
                    ),
                    StatCard(
                      label: 'Doanh thu tuần này',
                      value: AppFormatters.currency(report.weekRevenue),
                      icon: Icons.calendar_view_week_outlined,
                      color: AppColors.info,
                      trend: _trend(report.weekRevenue, report.lastWeekRevenue, 'so với tuần trước'),
                      trendUp: report.weekRevenue >= report.lastWeekRevenue,
                    ),
                    StatCard(
                      label: 'Tổng đơn hôm nay',
                      value: '${report.todayOrders}',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.primaryDark,
                    ),
                    StatCard(
                      label: 'Khách thành viên hôm nay',
                      value: '${report.todayMembers}',
                      icon: Icons.people_outline,
                      color: AppColors.warning,
                    ),
                  ],
                ),
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 80),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Doanh thu 7 ngày gần đây',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 16),
                      MockBarChart(data: report.revenueByDay),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                delay: const Duration(milliseconds: 140),
                child: SectionHeader(title: 'Món bán chạy · ${report.topFoodsDays} ngày'),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 180),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Lấy tối đa 3 món nhưng không vượt quá số món đang có,
                      // tránh lỗi vượt chỉ số khi danh sách ngắn hoặc rỗng.
                      for (int i = 0; i < math.min(3, report.topFoods.length); i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Text('${i + 1}.',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(report.topFoods[i].foodName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13.5)),
                              ),
                              const SizedBox(width: 8),
                              Text('${report.topFoods[i].soldQuantity} đã bán',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        if (i != math.min(3, report.topFoods.length) - 1) const Divider(height: 1),
                      ],
                      if (report.topFoods.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('Chưa có dữ liệu món bán chạy',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const FadeSlideIn(
                delay: Duration(milliseconds: 220),
                child: SectionHeader(title: 'Quản lý nhanh'),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                crossAxisCount: _quickManageColumns(constraints.maxWidth),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
                children: [
                  _QuickManage(
                      icon: Icons.people_alt_outlined,
                      label: 'Tài khoản',
                      imageUrl: 'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminAccounts)),
                  _QuickManage(
                      icon: Icons.menu_book_outlined,
                      label: 'Thực đơn',
                      imageUrl: 'https://cdn-icons-png.flaticon.com/512/2771/2771406.png',
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminMenu)),
                  _QuickManage(
                      icon: Icons.table_bar_outlined,
                      label: 'Bàn & khu vực',
                      imageUrl: 'https://cdn-icons-png.flaticon.com/512/1046/1046784.png',
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminTables)),
                  _QuickManage(
                      icon: Icons.local_offer_outlined,
                      label: 'Khuyến mãi',
                      imageUrl: 'https://cdn-icons-png.flaticon.com/512/3514/3514441.png',
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminPromotions)),
                  _QuickManage(
                      icon: Icons.bar_chart_outlined,
                      label: 'Báo cáo',
                      imageUrl: 'https://cdn-icons-png.flaticon.com/512/2920/2920277.png',
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminReports)),
                ]
                    .asMap()
                    .entries
                    .map((e) => FadeSlideIn.staggered(index: e.key, offsetY: 10, child: e.value))
                    .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickManage extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  /// URL ảnh tùy chọn. Khi có, hiển thị ảnh thay cho icon;
  /// nếu ảnh lỗi tải hoặc null thì vẫn dùng icon dự phòng.
  final String? imageUrl;

  const _QuickManage({
    required this.icon,
    required this.label,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hiển thị ảnh từ URL nếu có, fallback về icon nếu lỗi
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(icon, color: AppColors.textPrimary, size: 22),
                  // Trên web: nếu trang ảnh không cho phép CORS thì hiện bằng thẻ <img> của trình duyệt.
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                ),
              )
            else
              Icon(icon, color: AppColors.textPrimary, size: 22),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
