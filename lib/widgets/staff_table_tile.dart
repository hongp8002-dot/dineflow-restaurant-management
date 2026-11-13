import 'package:flutter/material.dart';

import '../models/table_model.dart';
import '../theme/app_colors.dart';
import '../theme/status_visuals.dart';
import '../utils/formatters.dart';
import 'app_animations.dart';
import 'status_badge.dart';
import 'status_legend.dart';

/// Ô bàn theo mockup Nhân viên Order: số bàn hai chữ số thật lớn, sức chứa
/// bên cạnh, trạng thái ở góc dưới. Màu nền theo trạng thái (trắng / nâu đen /
/// vàng). Khi được chọn (chuyển bàn, gộp bàn) có viền nâu đen bao ngoài và dấu ✓.
///
/// Dùng chung cho 4 màn: Sơ đồ bàn, Chọn bàn để Order, Chuyển bàn, Gộp bàn.
class StaffTableTile extends StatelessWidget {
  final TableModel table;
  final VoidCallback? onTap;
  final bool selected;

  const StaffTableTile({super.key, required this.table, this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final visual = tableTileVisual(table.status);
    final onDark = table.status == TableStatus.serving;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${table.number}, ${table.capacity} khách, ${tableStatusShortLabel(table.status)}',
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.95,
        // Viền chọn nằm bên trong ô nên kích thước ô không đổi khi chọn/bỏ chọn.
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: Curves.easeOut,
          padding: EdgeInsets.all(selected ? 3 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: selected ? Border.all(color: AppColors.ink, width: 2.4) : null,
          ),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            decoration: BoxDecoration(
              color: visual.background,
              borderRadius: BorderRadius.circular(selected ? 15 : 18),
              border: Border.all(color: visual.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tự thu nhỏ trên máy hẹp thay vì tràn ô.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        AppFormatters.tableCode(table.number),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: visual.foreground,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${table.capacity} khách',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: visual.muted),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        // Bàn đặt trước: kèm giờ khách tới để nhân viên biết ngay
                        table.status == TableStatus.reserved && table.nextReservation != null
                            ? '${tableStatusShortLabel(table.status)} ${AppFormatters.time(table.nextReservation!.dateTime)}'
                            : tableStatusShortLabel(table.status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: visual.foreground),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: AppMotion.fast,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: selected ? _CheckMark(onDark: onDark) : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dấu ✓ ở góc ô bàn đang chọn: trên nền tối là chấm trắng, trên nền sáng là vòng viền.
class _CheckMark extends StatelessWidget {
  final bool onDark;

  const _CheckMark({required this.onDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onDark ? AppColors.surface : Colors.transparent,
        border: onDark ? null : Border.all(color: AppColors.ink, width: 1.4),
      ),
      child: Icon(Icons.check_rounded, size: 14, color: AppColors.ink),
    );
  }
}

/// Lưới 3 cột các [StaffTableTile], các ô hiện lần lượt khi mở màn hình.
class StaffTableGrid extends StatelessWidget {
  final List<TableModel> tables;
  final void Function(TableModel table)? onTap;
  final bool Function(TableModel table)? isSelected;

  const StaffTableGrid({super.key, required this.tables, this.onTap, this.isSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        // Chiều cao cố định: đủ chỗ cho số bàn + trạng thái kể cả khi đang
        // chọn (viền chọn lấn vào trong) trên máy hẹp 320px.
        mainAxisExtent: 96,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        return FadeSlideIn.staggered(
          index: index,
          offsetY: 10,
          child: StaffTableTile(
            table: table,
            selected: isSelected?.call(table) ?? false,
            onTap: onTap == null ? null : () => onTap!(table),
          ),
        );
      },
    );
  }
}

/// Nhãn trạng thái bàn dạng viên thuốc, cùng màu với ô bàn
/// (đang phục vụ = nâu đen, đặt trước = vàng, trống = trắng).
class TableStatusPill extends StatelessWidget {
  final TableStatus status;

  const TableStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final visual = tableTileVisual(status);
    return StatusBadge(
      label: tableStatusShortLabel(status),
      color: visual.foreground,
      background: visual.background,
    );
  }
}

/// Chú thích màu ô bàn (ô vuông nhỏ) cho các màn có [StaffTableGrid].
class StaffTableLegend extends StatelessWidget {
  const StaffTableLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return StatusLegend(
      square: true,
      items: [
        for (final status in TableStatus.values)
          StatusLegendItem(
            tableTileVisual(status).background,
            tableStatusShortLabel(status),
            borderColor: status == TableStatus.empty ? AppColors.textSecondary : null,
          ),
      ],
    );
  }
}

/// Tiêu đề nhóm bàn theo khu vực, vd "Khu vực Tầng 1".
class StaffAreaTitle extends StatelessWidget {
  final String area;

  const StaffAreaTitle(this.area, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        'Khu vực $area',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      ),
    );
  }
}
