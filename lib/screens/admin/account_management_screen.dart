import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/admin_repository.dart';
import '../../models/user.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';

/// Quản lý tài khoản nhân viên (Admin).
/// Tạo / cập nhật / khoá / mở khoá tài khoản Order Staff và Thu ngân.
class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});
  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final _repo = AdminRepository.instance;

  List<User> _users = [];
  bool _loading = true;
  String? _error;

  // Filter
  String _roleFilter = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users = await _repo.fetchUsers(
        role: _roleFilter == 'all' ? null : _roleFilter,
        search: _search.isEmpty ? null : _search,
      );
      setState(() { _users = users; _loading = false; });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  // ── Tạo / Sửa tài khoản ─────────────────────────────────────────────────

  void _showUserForm([User? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserFormSheet(
        existing: existing,
        onSaved: (name, email, phone, role) async {
          Navigator.of(ctx).pop();
          setState(() => _loading = true);
          try {
            if (existing == null) {
              await _repo.createUser(name: name, email: email, phone: phone, role: role);
              _showSnack('Tạo tài khoản thành công. Mật khẩu mặc định: 123456');
            } else {
              await _repo.updateUser(existing.id, name: name, email: email, phone: phone, role: role);
              _showSnack('Cập nhật thành công');
            }
            _load();
          } on ApiException catch (e) {
            _showSnack(e.message, isError: true);
            setState(() => _loading = false);
          }
        },
      ),
    );
  }

  // ── Khoá / Mở khoá ──────────────────────────────────────────────────────

  Future<void> _toggleStatus(User user) async {
    try {
      final updated = await _repo.toggleUserStatus(user.id);
      setState(() {
        final i = _users.indexWhere((u) => u.id == user.id);
        if (i >= 0) _users[i] = updated;
      });
      _showSnack(updated.status == AccountStatus.locked
          ? 'Đã khoá tài khoản ${user.name}'
          : 'Đã kích hoạt tài khoản ${user.name}');
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  // ── "Xóa" = Khoá vĩnh viễn ──────────────────────────────────────────────

  Future<void> _confirmDelete(User user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa tài khoản', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          'Xóa "${user.name}"?\nTài khoản sẽ bị khoá và ẩn khỏi danh sách.\nLịch sử đơn hàng vẫn được giữ lại.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: AppColors.border), foregroundColor: AppColors.textPrimary),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    try {
      await _repo.deleteUser(user.id);
      setState(() => _users.removeWhere((u) => u.id == user.id));
      _showSnack('Đã xóa tài khoản ${user.name}');
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : null,
      ));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('Tài khoản', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => _showUserForm(),
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Thêm nhân viên',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Bộ lọc ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                AppSearchBar(
                  hint: 'Tìm tên, email...',
                  onChanged: (v) { _search = v; _load(); },
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in [
                        ('all', 'Tất cả'),
                        ('order_staff', 'NV Order'),
                        ('cashier', 'Thu ngân'),
                        ('customer', 'Khách hàng'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(f.$2),
                            selected: _roleFilter == f.$1,
                            onSelected: (_) { _roleFilter = f.$1; _load(); },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Danh sách ──
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: EmptyState(icon: Icons.error_outline_rounded, title: 'Lỗi tải dữ liệu', message: _error!));
    if (_users.isEmpty) return const Center(child: EmptyState(icon: Icons.person_off_outlined, title: 'Không có tài khoản', message: 'Bấm + để thêm nhân viên mới'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _UserTile(
          user: _users[i],
          onEdit: () => _showUserForm(_users[i]),
          onToggle: () => _toggleStatus(_users[i]),
          onDelete: () => _confirmDelete(_users[i]),
        ),
      ),
    );
  }
}

// ── Tile ────────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _UserTile({required this.user, required this.onEdit, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isLocked = user.status == AccountStatus.locked;
    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isLocked ? Border.all(color: AppColors.error.withOpacity(0.3)) : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryLight,
              child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: isLocked ? 'Khoá' : 'Hoạt động',
                        color: isLocked ? AppColors.error : const Color(0xFF1B6B3A),
                        background: isLocked
                            ? AppColors.error.withOpacity(0.12)
                            : const Color(0xFFDCF3E8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.email, style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(_roleLabel(user.role), style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'toggle') onToggle();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Sửa thông tin')),
                PopupMenuItem(value: 'toggle', child: Text(isLocked ? 'Kích hoạt' : 'Khoá tài khoản')),
                const PopupMenuItem(value: 'delete', child: Text('Xóa', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(UserRole role) => switch (role) {
    UserRole.admin => 'Quản trị viên',
    UserRole.orderStaff => 'NV Order',
    UserRole.cashier => 'Thu ngân',
    UserRole.customer => 'Khách hàng',
  };
}

// ── Form Sheet ───────────────────────────────────────────────────────────────

class _UserFormSheet extends StatefulWidget {
  final User? existing;
  final void Function(String name, String email, String phone, UserRole role) onSaved;

  const _UserFormSheet({this.existing, required this.onSaved});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  late final _emailCtrl = TextEditingController(text: widget.existing?.email);
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone);
  late UserRole _role = widget.existing?.role ?? UserRole.orderStaff;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scroll,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(isNew ? 'Thêm nhân viên' : 'Sửa tài khoản',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              AppTextField(controller: _nameCtrl, label: 'Họ và tên', hint: 'Nguyễn Văn A', validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null),
              const SizedBox(height: 12),
              AppTextField(controller: _emailCtrl, label: 'Email', hint: 'nhanvien@dineflow.vn', keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null),
              const SizedBox(height: 12),
              AppTextField(controller: _phoneCtrl, label: 'Số điện thoại (không bắt buộc)', hint: '0901234567', keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              Text('Vai trò', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in [UserRole.orderStaff, UserRole.cashier])
                    ChoiceChip(
                      label: Text(r == UserRole.orderStaff ? 'NV Order' : 'Thu ngân'),
                      selected: _role == r,
                      onSelected: (_) => setState(() => _role = r),
                    ),
                ],
              ),
              if (isNew) ...[
                const SizedBox(height: 12),
                Text('Mật khẩu mặc định: 123456 (nhân viên tự đổi sau khi đăng nhập)', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: isNew ? 'Tạo tài khoản' : 'Lưu thay đổi',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onSaved(_nameCtrl.text.trim(), _emailCtrl.text.trim(), _phoneCtrl.text.trim(), _role);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AppSearchBar simple wrapper (nếu chưa có) ────────────────────────────────

class AppSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const AppSearchBar({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
      ),
    );
  }
}
