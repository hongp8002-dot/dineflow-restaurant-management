import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/mock_data.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/live_tables.dart';
import '../../widgets/staff_table_tile.dart';
import '../../widgets/status_badge.dart';

/// Sơ đồ bàn theo khu vực - màn hình chính của Nhân viên Order.
/// Kéo xuống để làm mới trạng thái bàn.
class TableManagementScreen extends StatelessWidget {
  const TableManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LiveTables(
      builder: (context, refresh) {
        final user = MockData.currentOrderStaff;

        return Scaffold(
          backgroundColor: AppColors.surfaceAlt,
          body: Column(
            children: [
              AppHeaderBand(
                caption: '${user.name} · ${user.role.label}',
                title: 'Sơ đồ bàn',
                titleTrailing: StatusBadge(
                  label: 'Phục vụ',
                  color: AppColors.textOnPrimary,
                  background: AppColors.primary,
                ),
                showBack: false,
                trailing: IconButton(
                  tooltip: 'Lịch đặt bàn',
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.reservationList),
                  icon: Icon(Icons.event_note_rounded, color: AppColors.textPrimary),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    children: [
                      const FadeSlideIn(offsetY: 8, child: StaffTableLegend()),
                      const SizedBox(height: 18),
                      for (final area in MockData.areas) ...[
                        StaffAreaTitle(area),
                        StaffTableGrid(
                          tables: MockData.tables.where((t) => t.area == area).toList(),
                          onTap: (table) => Navigator.of(context)
                              .pushNamed(AppRoutes.staffTableDetail, arguments: table.id),
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
