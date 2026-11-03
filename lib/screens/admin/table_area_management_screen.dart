import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/admin_repository.dart';
import '../../models/table_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/status_visuals.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/status_badge.dart';

/// Quản lý bàn & khu vực.
/// Kết nối thật với AdminRepository.
/// - `is_locked` (PATCH /admin/tables/{id}/toggle-locked): khoá/mở khoá tạm thời.
/// - `is_active` (PATCH /admin/tables/{id}/toggle-active): vô hiệu hoá hẳn bàn.
class TableAreaManagementScreen extends StatefulWidget {
  const TableAreaManagementScreen({super.key});

  @override
  State<TableAreaManagementScreen> createState() => _TableAreaManagementScreenState();
}

class _TableAreaManagementScreenState extends State<TableAreaManagementScreen> {
  final _repo = AdminRepository.instance;

  List<TableModel> _tables = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _tables = await _repo.fetchTables();
      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  // ── Khoá / Mở khoá tạm thời (is_locked) ─────────────────────────────────

  Future<void> _toggleLock(TableModel table) async {
    if (table.status == TableStatus.serving) {
      _snack('Không thể khoá bàn đang phục vụ', isWarn: true);
      return;
    }
    try {
      final updated = await _repo.toggleTableLocked(table.id);
      setState(() {
        final i = _tables.indexWhere((t) => t.id == table.id);
        if (i >= 0) _tables[i] = updated;
      });
      _snack(updated.isLocked ? 'Đã khoá ${table.number}' : 'Đã mở khoá ${table.number}');
    } on ApiException catch (e) {
      _snack(e.message, isError: true);
    }
  }

  // ── Vô hiệu hoá hẳn (is_active) ─────────────────────────────────────────

  Future<void> _toggleActive(TableModel table) async {
    final action = table.isActive ? 'vô hiệu hoá' : 'kích hoạt lại';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${table.isActive ? "Vô hiệu hoá" : "Kích hoạt"} bàn', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Bạn muốn $action "${table.number}"?\n${table.isActive ? "Bàn sẽ không hiển thị với NV Order." : "Bàn sẽ xuất hiện lại trong sơ đồ."}',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: AppColors.border), foregroundColor: AppColors.textPrimary),
            child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: table.isActive ? AppColors.error : AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(table.isActive ? 'Vô hiệu hoá' : 'Kích hoạt')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final updated = await _repo.toggleTableActive(table.id);
      setState(() {
        final i = _tables.indexWhere((t) => t.id == table.id);
        if (i >= 0) _tables[i] = updated;
      });
      _snack(updated.isActive ? '${table.number} đã kích hoạt' : '${table.number} đã vô hiệu hoá');
    } on ApiException catch (e) {
      _snack(e.message, isError: true);
    }
  }

  // ── Form thêm / sửa bàn ──────────────────────────────────────────────────

  void _showTableForm([TableModel? table]) {
    final areas = _tables.map((t) => t.area).toSet().toList();
    final numberCtrl = TextEditingController(text: table?.number ?? '');
    final capacityCtrl = TextEditingController(text: table != null ? '${table.capacity}' : '');
    String selectedArea = table?.area ?? (areas.isNotEmpty ? areas.first : '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (bCtx, setSheet) {
          final bottomInset = MediaQuery.of(bCtx).viewInsets.bottom;
          return Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                  Text(table == null ? 'Thêm bàn mới' : 'Sửa bàn', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: numberCtrl, label: 'Tên bàn', hint: 'VD: Bàn 5, Bàn VIP 1',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên bàn' : null,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: capacityCtrl, label: 'Sức chứa (người)', hint: 'VD: 4',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Vui lòng nhập sức chứa';
                      if (int.tryParse(v.trim()) == null || int.parse(v.trim()) < 1) return 'Sức chứa phải là số nguyên dương';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Text('Khu vực', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  // Cho phép nhập thủ công hoặc chọn khu vực đã có
                  if (areas.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: areas.contains(selectedArea) ? selectedArea : null,
                      hint: const Text('Chọn khu vực'),
                      decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border))),
                      items: areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                      onChanged: (v) => setSheet(() => selectedArea = v ?? selectedArea),
                    ),
                    const SizedBox(height: 8),
                    Text('hoặc nhập khu vực mới:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                  ],
                  AppTextField(
                    controller: TextEditingController(text: areas.contains(selectedArea) ? selectedArea : ''),
                    label: 'Khu vực',
                    hint: 'VD: Tầng 1, Ngoài trời',
                    onChanged: (v) => selectedArea = v,
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: table == null ? 'Thêm bàn' : 'Lưu thay đổi',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.of(bCtx).pop();
                      setState(() => _loading = true);
                      try {
                        if (table == null) {
                          await _repo.createTable(
                            number: numberCtrl.text.trim(),
                            area: selectedArea.trim(),
                            capacity: int.parse(capacityCtrl.text.trim()),
                          );
                          _snack('Đã thêm bàn "${numberCtrl.text.trim()}"');
                        } else {
                          await _repo.updateTable(
                            table.id,
                            number: numberCtrl.text.trim(),
                            area: selectedArea.trim(),
                            capacity: int.parse(capacityCtrl.text.trim()),
                          );
                          _snack('Đã cập nhật "${table.number}"');
                        }
                        _load();
                      } on ApiException catch (e) {
                        _snack(e.message, isError: true);
                        setState(() => _loading = false);
                      }
                    },
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _snack(String msg, {bool isError = false, bool isWarn = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : isWarn ? AppColors.warning : null,
      ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final areas = _tables.map((t) => t.area).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý bàn & khu vực', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Thêm bàn', onPressed: () => _showTableForm()),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ]))
                : _tables.isEmpty
                    ? Center(child: Text('Chưa có bàn nào', style: TextStyle(color: AppColors.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          children: [
                            for (final area in areas) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8, top: 4),
                                child: Text('Khu vực $area', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                              ),
                              for (final t in _tables.where((t) => t.area == area))
                                _TableTile(
                                  table: t,
                                  onEdit: () => _showTableForm(t),
                                  onToggleLock: () => _toggleLock(t),
                                  onToggleActive: () => _toggleActive(t),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
      ),
    );
  }
}

// ── Tile bàn ────────────────────────────────────────────────────────────────

class _TableTile extends StatelessWidget {
  final TableModel table;
  final VoidCallback onEdit;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleActive;

  const _TableTile({required this.table, required this.onEdit, required this.onToggleLock, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    final visual = tableStatusVisual(table.status);
    final isInactive = !table.isActive;

    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isInactive ? AppColors.surfaceAlt : (table.isLocked ? AppColors.surfaceAlt : AppColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isInactive ? AppColors.border.withOpacity(0.5) : AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(children: [
          Icon(
            isInactive ? Icons.table_bar_outlined : (table.isLocked ? Icons.lock_outline_rounded : Icons.table_bar_rounded),
            color: isInactive ? AppColors.textSecondary : visual.color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(table.number, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isInactive ? AppColors.textSecondary : AppColors.textPrimary)),
              Text('Sức chứa ${table.capacity} khách', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Badge trạng thái
            if (isInactive)
              StatusBadge(label: 'Vô hiệu', color: AppColors.error, background: AppColors.errorBg)
            else if (table.isLocked)
              StatusBadge(label: 'Khoá', color: AppColors.warning, background: AppColors.warning.withValues(alpha: 0.12))
            else
              StatusBadge(label: table.status.label, color: visual.color, background: visual.background),
            const SizedBox(height: 4),
            // Actions
            Row(mainAxisSize: MainAxisSize.min, children: [
              // Khoá / Mở khoá tạm thời
              IconButton(
                icon: Icon(
                  table.isLocked ? Icons.lock_open_outlined : Icons.lock_outline_rounded,
                  size: 18, color: table.isLocked ? AppColors.success : AppColors.warning,
                ),
                tooltip: table.isLocked ? 'Mở khoá' : 'Khoá tạm',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36), padding: EdgeInsets.zero,
                onPressed: isInactive ? null : onToggleLock,
              ),
              // Sửa
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Sửa bàn',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36), padding: EdgeInsets.zero,
                onPressed: onEdit,
              ),
              // Vô hiệu hoá / Kích hoạt
              IconButton(
                icon: Icon(
                  isInactive ? Icons.power_settings_new_rounded : Icons.block_outlined,
                  size: 18, color: isInactive ? AppColors.success : AppColors.error,
                ),
                tooltip: isInactive ? 'Kích hoạt bàn' : 'Vô hiệu hoá bàn',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36), padding: EdgeInsets.zero,
                onPressed: onToggleActive,
              ),
            ]),
          ]),
        ]),
      ),
    );
  }
}
