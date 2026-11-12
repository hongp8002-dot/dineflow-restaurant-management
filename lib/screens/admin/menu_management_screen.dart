import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/admin_repository.dart';
import '../../models/food.dart';
import '../../models/food_category.dart';
import '../../models/food_option.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/food_image.dart';
import '../../widgets/status_badge.dart';

/// Quản lý thực đơn: danh sách món + danh mục.
/// Kết nối thật với AdminRepository (Laravel API).
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final _repo = AdminRepository.instance;

  // ── State ──
  List<Food> _foods = [];
  List<FoodCategory> _categories = [];
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
      final results = await Future.wait([
        _repo.fetchFoods(),
        _repo.fetchCategories(),
      ]);
      setState(() {
        _foods = results[0] as List<Food>;
        _categories = results[1] as List<FoodCategory>;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  // ── Toggle ẩn/hiện món ──────────────────────────────────────────────────

  Future<void> _toggleAvailable(Food food) async {
    try {
      final updated = await _repo.toggleFoodAvailable(food.id);
      setState(() {
        final i = _foods.indexWhere((f) => f.id == food.id);
        if (i >= 0) _foods[i] = updated;
      });
      _snack(updated.isAvailable ? '"${food.name}" đã mở bán trở lại' : '"${food.name}" tạm ẩn khỏi thực đơn');
    } on ApiException catch (e) {
      _snack(e.message, isError: true);
    }
  }

  // ── Xóa món ──────────────────────────────────────────────────────────────

  Future<void> _confirmDeleteFood(Food food) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa món ăn', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          'Xóa vĩnh viễn "${food.name}"?\n\nHành động này không thể hoàn tác.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: AppColors.border),
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteFood(food.id);
      setState(() => _foods.removeWhere((f) => f.id == food.id));
      _snack('Đã xóa "${food.name}"');
    } on ApiException catch (e) {
      _snack(e.message, isError: true);
    }
  }

  // ── Form món ──────────────────────────────────────────────────────────────

  void _showFoodForm([Food? food]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodFormSheet(
        existing: food,
        categories: _categories,
        onSaved: (name, price, desc, categoryId, isAvailable) async {
          Navigator.of(ctx).pop();
          setState(() => _loading = true);
          try {
            if (food == null) {
              await _repo.createFood(
                name: name, price: price, description: desc,
                categoryId: int.tryParse(categoryId) ?? 0, isAvailable: isAvailable,
              );
              _snack('Đã thêm "$name"');
            } else {
              await _repo.updateFood(
                food.id,
                name: name, price: price, description: desc,
                categoryId: int.tryParse(categoryId), isAvailable: isAvailable,
              );
              _snack('Đã cập nhật "$name"');
            }
            _load();
          } on ApiException catch (e) {
            _snack(e.message, isError: true);
            setState(() => _loading = false);
          }
        },
      ),
    );
  }

  // ── Form danh mục ─────────────────────────────────────────────────────────

  void _showCategoryForm([FoodCategory? cat]) {
    final nameCtrl = TextEditingController(text: cat?.name ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FormSheetWrapper(
        title: cat == null ? 'Thêm danh mục' : 'Sửa danh mục',
        formKey: formKey,
        children: [
          AppTextField(
            controller: nameCtrl,
            label: 'Tên danh mục',
            hint: 'VD: Đồ uống nóng',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên danh mục' : null,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: cat == null ? 'Thêm danh mục' : 'Lưu thay đổi',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(ctx).pop();
              setState(() => _loading = true);
              try {
                if (cat == null) {
                  await _repo.createCategory(name: nameCtrl.text.trim());
                  _snack('Đã thêm danh mục "${nameCtrl.text.trim()}"');
                } else {
                  await _repo.updateCategory(cat.id, name: nameCtrl.text.trim());
                  _snack('Đã cập nhật "${cat.name}"');
                }
                _load();
              } on ApiException catch (e) {
                _snack(e.message, isError: true);
                setState(() => _loading = false);
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Xóa danh mục ─────────────────────────────────────────────────────────
  // Nếu danh mục có món: hỏi xác nhận xóa luôn các món bên trong.
  // Thực hiện: xóa từng món trước → rồi mới xóa danh mục.

  Future<void> _confirmDeleteCategory(FoodCategory cat) async {
    final foodsInCat = _foods.where((f) => f.categoryId == cat.id).toList();
    final hasFoods = foodsInCat.isNotEmpty;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa danh mục', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          hasFoods
              ? 'Danh mục "${cat.name}" đang có ${foodsInCat.length} món.\n\n'
                'Xóa danh mục sẽ xóa luôn tất cả các món bên trong. '
                'Hành động này không thể hoàn tác.'
              : 'Xóa "${cat.name}"?\nHành động này không thể hoàn tác.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: AppColors.border),
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(hasFoods ? 'Xóa tất cả' : 'Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      // Xóa từng món trong danh mục trước
      for (final food in foodsInCat) {
        await _repo.deleteFood(food.id);
      }
      // Rồi mới xóa danh mục (backend không còn bị từ chối do có món)
      await _repo.deleteCategory(cat.id);
      setState(() {
        _foods.removeWhere((f) => f.categoryId == cat.id);
        _categories.removeWhere((c) => c.id == cat.id);
        _loading = false;
      });
      _snack('Đã xóa danh mục "${cat.name}"'
          '${hasFoods ? ' và ${foodsInCat.length} món' : ''}');
    } on ApiException catch (e) {
      _snack(e.message, isError: true);
      _load(); // reload để đồng bộ lại trạng thái
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? AppColors.error : null));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quản lý thực đơn', style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(tabs: [Tab(text: 'Món ăn'), Tab(text: 'Danh mục')]),
          actions: [
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Thêm mới',
                onPressed: () {
                  final tab = DefaultTabController.of(ctx).index;
                  if (tab == 0) _showFoodForm(); else _showCategoryForm();
                },
              ),
            ),
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
                  : TabBarView(children: [
                      _FoodTab(
                        foods: _foods,
                        onEdit: _showFoodForm,
                        onToggle: _toggleAvailable,
                        onDelete: _confirmDeleteFood,
                      ),
                      _CategoryTab(
                        categories: _categories,
                        foods: _foods,
                        onEdit: _showCategoryForm,
                        onDelete: _confirmDeleteCategory,
                      ),
                    ]),
        ),
      ),
    );
  }
}

// ── Tab Món ăn ──────────────────────────────────────────────────────────────

class _FoodTab extends StatelessWidget {
  final List<Food> foods;
  final void Function(Food) onEdit;
  final void Function(Food) onToggle;
  final void Function(Food) onDelete;

  const _FoodTab({
    required this.foods,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (foods.isEmpty) {
      return Center(child: Text('Chưa có món nào', style: TextStyle(color: AppColors.textSecondary)));
    }
    return RefreshIndicator(
      onRefresh: () async {}, // parent handles
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: foods.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final food = foods[i];
          return FadeSlideIn.staggered(
            index: i,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: food.isAvailable ? AppColors.surface : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 48, height: 48,
                        child: food.image != null
                            ? FoodImage(food: food, borderRadius: 10, iconSize: 22)
                            : Container(
                                decoration: BoxDecoration(color: food.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                child: Icon(food.icon, color: food.color, size: 22),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(food.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: food.isAvailable ? AppColors.textPrimary : AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(AppFormatters.currency(food.price), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          StatusBadge(
                            label: food.isAvailable ? 'Còn món' : 'Tạm ẩn',
                            color: food.isAvailable ? AppColors.success : AppColors.error,
                            background: food.isAvailable ? AppColors.successBg : AppColors.errorBg,
                          ),
                        ]),
                      ),
                      // Cột nút: Sửa | Ẩn/Hiện | Xóa
                      Column(children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Sửa',
                          onPressed: () => onEdit(food),
                        ),
                        IconButton(
                          icon: Icon(
                            food.isAvailable ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: food.isAvailable ? AppColors.warning : AppColors.success,
                          ),
                          tooltip: food.isAvailable ? 'Tạm ẩn' : 'Mở bán',
                          onPressed: () => onToggle(food),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                          tooltip: 'Xóa',
                          onPressed: () => onDelete(food),
                        ),
                      ]),
                    ],
                  ),
                  if (food.options.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.only(top: 8, bottom: 6), child: Divider(height: 1)),
                    _OptionsSection(options: food.options),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OptionsSection extends StatelessWidget {
  final List<FoodOption> options;
  const _OptionsSection({required this.options});

  @override
  Widget build(BuildContext context) {
    final sizes = options.where((o) => o.type == FoodOptionType.size).toList();
    final toppings = options.where((o) => o.type == FoodOptionType.topping).toList();
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (sizes.isNotEmpty) _OptionRow(label: 'Size', options: sizes, color: AppColors.info),
        if (sizes.isNotEmpty && toppings.isNotEmpty) const SizedBox(height: 4),
        if (toppings.isNotEmpty) _OptionRow(label: 'Topping', options: toppings, color: AppColors.primary),
      ]),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final List<FoodOption> options;
  final Color color;
  const _OptionRow({required this.label, required this.options, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text('$label: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ),
      Expanded(
        child: Wrap(
          spacing: 4, runSpacing: 4,
          children: options.map((o) {
            final extra = o.extraPrice > 0 ? ' +${AppFormatters.currency(o.extraPrice)}' : '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text('${o.name}$extra', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

// ── Tab Danh mục ────────────────────────────────────────────────────────────

class _CategoryTab extends StatelessWidget {
  final List<FoodCategory> categories;
  final List<Food> foods;
  final void Function(FoodCategory) onEdit;
  final void Function(FoodCategory) onDelete;

  const _CategoryTab({required this.categories, required this.foods, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Center(child: Text('Chưa có danh mục nào', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height:10),
      itemBuilder: (ctx, i) {
        final cat = categories[i];
        final count = foods.where((f) => f.categoryId == cat.id).length;
        return FadeSlideIn.staggered(
          index: i,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: AppColors.softShadow),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                child: Icon(cat.icon, color: AppColors.textPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('$count món', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ])),
              IconButton(icon: const Icon(Icons.edit_outlined, size: 20), tooltip: 'Sửa', onPressed: () => onEdit(cat)),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                tooltip: 'Xóa',
                onPressed: () => onDelete(cat),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Food Form Sheet ──────────────────────────────────────────────────────────

class _FoodFormSheet extends StatefulWidget {
  final Food? existing;
  final List<FoodCategory> categories;
  final void Function(String name, double price, String desc, String categoryId, bool isAvailable) onSaved;

  const _FoodFormSheet({this.existing, required this.categories, required this.onSaved});

  @override
  State<_FoodFormSheet> createState() => _FoodFormSheetState();
}

class _FoodFormSheetState extends State<_FoodFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  late final _priceCtrl = TextEditingController(text: widget.existing != null ? widget.existing!.price.toStringAsFixed(0) : '');
  late final _descCtrl = TextEditingController(text: widget.existing?.description);
  late String? _categoryId = widget.existing?.categoryId ?? (widget.categories.isNotEmpty ? widget.categories.first.id : null);
  late bool _isAvailable = widget.existing?.isAvailable ?? true;

  @override
  void dispose() {
    _nameCtrl.dispose(); _priceCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return _FormSheetWrapper(
      title: isNew ? 'Thêm món mới' : 'Sửa món',
      formKey: _formKey,
      children: [
        AppTextField(
          controller: _nameCtrl, label: 'Tên món', hint: 'VD: Cà phê sữa đá',
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên món' : null,
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _priceCtrl, label: 'Giá (đồng)', hint: 'VD: 45000',
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá';
            if (double.tryParse(v.replaceAll('.', '').replaceAll(',', '')) == null) return 'Giá không hợp lệ';
            return null;
          },
        ),
        const SizedBox(height: 14),
        AppTextField(controller: _descCtrl, label: 'Mô tả (không bắt buộc)', hint: 'Mô tả ngắn về món', maxLines: 2),
        const SizedBox(height: 14),
        if (widget.categories.isNotEmpty) ...[
          Text('Danh mục', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _categoryId,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            ),
            items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
          child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            title: const Text('Còn phục vụ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(_isAvailable ? 'Hiển thị trong thực đơn' : 'Tạm ẩn khỏi thực đơn', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            value: _isAvailable, activeColor: AppColors.success,
            onChanged: (v) => setState(() => _isAvailable = v),
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: isNew ? 'Thêm món' : 'Lưu thay đổi',
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (_categoryId == null) return;
            widget.onSaved(
              _nameCtrl.text.trim(),
              double.parse(_priceCtrl.text.replaceAll('.', '').replaceAll(',', '')),
              _descCtrl.text.trim(),
              _categoryId!,
              _isAvailable,
            );
          },
        ),
      ],
    );
  }
}

// ── Khung form chung ────────────────────────────────────────────────────────

class _FormSheetWrapper extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  const _FormSheetWrapper({required this.title, required this.formKey, required this.children});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
