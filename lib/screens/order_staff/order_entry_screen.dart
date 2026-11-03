import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/mock_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/live_tables.dart';
import '../../widgets/staff_table_tile.dart';

/// Tab Order: chọn bàn cần lên order rồi chuyển tới màn hình Order món.
/// Kéo xuống để làm mới trạng thái bàn.
class OrderEntryScreen extends StatelessWidget {
  const OrderEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LiveTables(
      builder: (context, refresh) {
        final areas = MockData.areas;

        return Scaffold(
          backgroundColor: AppColors.surfaceAlt,
          body: Column(
            children: [
              AppHeaderBand(
                caption: '${MockData.tables.length} bàn · ${areas.length} khu vực',
                title: 'Chọn bàn để Order',
                showBack: false,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      FadeSlideIn(
                        offsetY: 8,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 22, color: AppColors.textPrimary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Chọn một bàn để mở thực đơn và bắt đầu lên order cho khách.',
                                  style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final area in areas) ...[
                        StaffAreaTitle(area),
                        StaffTableGrid(
                          tables: MockData.tables.where((t) => t.area == area).toList(),
                          onTap: (table) => Navigator.of(context)
                              .pushNamed(AppRoutes.staffCreateOrder, arguments: table.id),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
