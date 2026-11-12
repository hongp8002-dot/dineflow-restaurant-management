import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../data/order_staff_repository.dart';
import '../../models/table_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/live_data.dart';
import '../../widgets/staff_table_tile.dart';

/// UI gộp bàn: chọn thêm bàn, gộp đơn của các bàn nguồn vào bàn hiện tại.
///
/// Bàn hiện tại ([initialTableId]) là bàn ĐÍCH — các bàn còn lại được chọn
/// là bàn NGUỒN. Server sẽ chuyển toàn bộ món của bàn nguồn vào đơn của
/// bàn đích, rồi giải phóng bàn nguồn.
///
/// Gọi API thật `POST /tables/{sourceId}/merge` cho từng bàn nguồn.
class MergeTableScreen extends StatefulWidget {
  final String initialTableId;
  const MergeTableScreen({super.key, required this.initialTableId});

  @override
  State<MergeTableScreen> createState() => _MergeTableScreenState();
}

class _MergeTableScreenState extends State<MergeTableScreen> {
  // _selectedIds bao gồm initialTableId (bàn đích) cộng các bàn nguồn được chọn.
  late final List<String> _selectedIds = [widget.initialTableId];
  bool _loading = false;

  void _toggle(TableModel table) {
    // Không cho bỏ bàn đích (initialTableId).
    if (table.id == widget.initialTableId) return;
    setState(() {
      if (_selectedIds.contains(table.id)) {
        _selectedIds.remove(table.id);
      } else {
        _selectedIds.add(table.id);
      }
    });
  }

  Future<void> _confirm(TableModel targetTable) async {
    if (_loading) return;
    // Danh sách các bàn nguồn (không kể bàn đích).
    final sourceIds = _selectedIds.where((id) => id != widget.initialTableId).toList();
    if (sourceIds.isEmpty) return;

    setState(() => _loading = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await OrderStaffRepository.instance.mergeIntoTable(
        widget.initialTableId,
        sourceTableIds: sourceIds,
      );
      await AppData.refresh(
        {LiveSource.tables, LiveSource.orders},
        force: true,
      );
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã gộp ${sourceIds.length} bàn vào ${targetTable.number}'),
        ),
      );
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      LiveData(sources: const {LiveSource.tables}, builder: (context, _) => _buildContent(context));

  Widget _buildContent(BuildContext context) {
    // Chỉ hiển thị bàn đang phục vụ (có đơn) làm bàn NGUỒN:
    // Backend yêu cầu bàn nguồn phải có trạng thái Serving (TableOperationController@merge).
    // Bàn trống không có đơn → chọn vào sẽ bị server từ chối 422.
    // Bàn đích (initialTableId) hiển thị riêng qua chip, không phụ thuộc danh sách này.
    final allTables = MockData.tables
        .where((t) => t.isActive && !t.isLocked && t.status == TableStatus.serving)
        .toList();

    final targetTable = MockData.tables.where((t) => t.id == widget.initialTableId).firstOrNull;
    if (targetTable == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final selectedTables = [
      for (final id in _selectedIds)
        MockData.tables.where((t) => t.id == id).firstOrNull,
    ].whereType<TableModel>().toList();

    final sourceCount = _selectedIds.length - 1; // trừ bàn đích
    final canConfirm = sourceCount >= 1;

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: Column(
        children: [
          AppHeaderBand(
            title: 'Gộp bàn',
            subtitle: 'Gộp đơn của các bàn khác vào ${targetTable.number}',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                // ── Tiêu đề bàn đích ─────────────────────────────────────────
                Text(
                  'Bàn đích: ${targetTable.number}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Các bàn bạn chọn bên dưới sẽ được gộp VÀO bàn này',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // ── Danh sách đã chọn (chip) ──────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedValueText(
                    sourceCount == 0
                        ? 'Chưa chọn bàn nguồn nào'
                        : 'Đã chọn $sourceCount bàn nguồn',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSize(
                  duration: AppMotion.normal,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final table in selectedTables)
                        _SelectedTableChip(
                          key: ValueKey(table.id),
                          label: table.number,
                          // Không cho bỏ bàn đích
                          onRemove: table.id == widget.initialTableId ? null : () => _toggle(table),
                          isTarget: table.id == widget.initialTableId,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Lưới tất cả bàn ──────────────────────────────────────────
                Text(
                  'Chọn bàn cần gộp vào',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chỉ hiển thị bàn đang phục vụ · Bàn đích (${targetTable.number}) không thể bỏ chọn',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                StaffTableGrid(
                  tables: allTables,
                  isSelected: (table) => _selectedIds.contains(table.id),
                  onTap: _toggle,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton(
                label: canConfirm
                    ? 'Gộp $sourceCount bàn vào ${targetTable.number}'
                    : 'Chọn ít nhất 1 bàn nguồn',
                isLoading: _loading,
                onPressed: canConfirm ? () => _confirm(targetTable) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Viên trắng ghi tên bàn đã chọn kèm nút ×.
class _SelectedTableChip extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;
  final bool isTarget;

  const _SelectedTableChip({
    super.key,
    required this.label,
    required this.onRemove,
    this.isTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      offsetY: 6,
      duration: AppMotion.fast,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(
          color: isTarget ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isTarget ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTarget) ...[
              Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.textPrimary),
              const SizedBox(width: 4),
            ],
            Text(
              isTarget ? '$label (đích)' : label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'Bỏ $label',
              child: PressScale(
                onTap: onRemove,
                scale: 0.85,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    isTarget ? Icons.lock_rounded : Icons.close_rounded,
                    size: 17,
                    color: onRemove == null ? AppColors.border : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
