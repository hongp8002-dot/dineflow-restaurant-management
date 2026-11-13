import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/cart_store.dart';
import '../../data/mock_data.dart';
import '../../data/order_repository.dart';
import '../../models/food.dart';
import '../../models/food_option.dart';
import '../../models/order_item.dart';
import '../../models/table_model.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_header_band.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/quantity_stepper.dart';

/// Màn hình Order món tại bàn: chọn món, size/topping, số lượng, ghi chú, gửi order.
///
/// Theo mockup "Order món": số lượng chỉnh ngay trên từng dòng món (nút + khi
/// chưa chọn, bộ − số + khi đã chọn), tổng tiền và nút Gửi Order ở thanh dưới.
///
/// Món có size/topping (nhóm chốt 13/11, cùng quy tắc màn chi tiết món của khách): bấm + mở
/// bảng chọn, size mặc định là size đầu tiên, topping chọn thêm tùy ý. Mỗi tổ hợp tùy chọn
/// là một dòng riêng (vd Trà sữa M và Trà sữa L), mỗi dòng có số lượng và ghi chú riêng.
/// Giá cuối cùng do server tính từ option_ids.
class CreateOrderScreen extends StatefulWidget {
  final String? tableId;
  const CreateOrderScreen({super.key, this.tableId});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final CartStore _draft = AppCart.staffOrder;
  String? _selectedCategoryId;
  String _keyword = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _draft.clear();
    _draft.addListener(_onChanged);
  }

  @override
  void dispose() {
    _draft.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  TableModel? get _table {
    if (widget.tableId == null) return null;
    // Dùng where().firstOrNull thay firstWhere để tránh "Bad state: No element"
    // khi MockData.tables đang được refresh bởi LiveData ở màn trước.
    final matches = MockData.tables.where((t) => t.id == widget.tableId);
    return matches.isEmpty ? null : matches.first;
  }

  List<Food> get _filteredFoods {
    return MockData.foods.where((food) {
      final matchesCategory = _selectedCategoryId == null || food.categoryId == _selectedCategoryId;
      final matchesKeyword =
          _keyword.trim().isEmpty || food.name.toLowerCase().contains(_keyword.trim().toLowerCase());
      return matchesCategory && matchesKeyword && food.isAvailable;
    }).toList();
  }

  /// Dòng của món KHÔNG có tùy chọn trong order đang tạo. Mỗi món chỉ có một dòng: chạm lại
  /// vào món đã có thì tăng số lượng của chính dòng đó, không đẻ dòng trùng.
  OrderItem? _lineOf(Food food) {
    for (final item in _draft.items) {
      if (item.foodId == food.id) return item;
    }
    return null;
  }

  /// Mọi dòng của một món (món có size/topping có thể có nhiều dòng, mỗi tổ hợp một dòng).
  List<OrderItem> _linesOf(Food food) => _draft.items.where((i) => i.foodId == food.id).toList();

  /// Bấm + / chạm vào món: món có tùy chọn thì mở bảng chọn, không có thì thêm 1 phần.
  void _addFood(Food food) {
    if (food.options.isNotEmpty) {
      _pickOptions(food);
      return;
    }
    final existing = _lineOf(food);
    if (existing != null) {
      _draft.updateQuantity(existing.id, existing.quantity + 1);
      return;
    }
    _addLine(food, const []);
  }

  Future<void> _pickOptions(Food food) async {
    final options = await showModalBottomSheet<List<FoodOption>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionSheet(food: food),
    );
    if (options == null || !mounted) return;

    // Cùng tổ hợp tùy chọn và chưa có ghi chú → cộng vào dòng sẵn có thay vì tạo dòng trùng.
    String key(Iterable<FoodOption> list) => (list.map((o) => o.id).toList()..sort()).join(',');
    final wanted = key(options);
    for (final line in _linesOf(food)) {
      if (key(line.selectedOptions) == wanted && line.note.isEmpty) {
        _draft.updateQuantity(line.id, line.quantity + 1);
        return;
      }
    }
    _addLine(food, options);
  }

  void _addLine(Food food, List<FoodOption> options) {
    _draft.addItem(OrderItem(
      id: '${food.id}-${DateTime.now().microsecondsSinceEpoch}',
      foodId: food.id,
      foodName: food.name,
      price: food.price,
      quantity: 1,
      selectedOptions: options,
    ));
  }

  /// Đặt số lượng từ bộ − số +; giảm về 0 thì món rời khỏi order.
  void _setQuantity(Food food, int quantity) {
    final line = _lineOf(food);
    if (line == null) {
      if (quantity > 0) _addFood(food);
      return;
    }
    _draft.updateQuantity(line.id, quantity);
  }

  Future<void> _editNote(OrderItem item) async {
    // Lấy navigator context trước khi await để không dùng context sau khoảng chờ.
    // useRootNavigator: true tránh lỗi "_dependents.isEmpty" khi parent widget
    // bị dispose trong lúc dialog đang mở (vd do LiveData refresh).
    final nav = Navigator.of(context, rootNavigator: true);
    final result = await showDialog<String>(
      context: nav.context,
      useRootNavigator: true,
      // _NoteDialog là StatefulWidget riêng: controller được tạo trong initState()
      // và huỷ trong dispose() — Flutter gọi dispose() SAU KHI animation đóng
      // dialog hoàn tất, tránh lỗi "TextEditingController used after being disposed".
      builder: (ctx) => _NoteDialog(
        foodName: item.foodName,
        initialNote: item.note,
      ),
    );
    // Kiểm tra mounted trước khi cập nhật state để tránh setState sau dispose.
    if (result != null && mounted) _draft.updateNote(item.id, result.trim());
  }

  /// Hỏi lại trước khi rời màn hình khi order đang có món, tránh mất công nhập.
  Future<bool> _confirmDiscard() async {
    if (_draft.isEmpty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Huỷ order đang tạo?'),
        content:
            Text('Order hiện có ${_draft.totalQuantity} món chưa gửi. Rời khỏi màn hình sẽ mất các món này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tiếp tục order')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Huỷ order', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  /// Gửi order lên server. Thành công: tải lại bàn + đơn rồi đóng màn; lỗi: giữ nguyên các món đã chọn.
  Future<void> _submitOrder() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    // Lấy trước khi await để không dùng context sau khoảng chờ.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));

    try {
      final result = await OrderRepository.instance.create(tableId: widget.tableId, items: _draft.items);
      // Đơn đã tạo ở server: đóng màn ngay, tải lại bàn + đơn chạy nền (các màn phía sau tự cập nhật).
      unawaited(AppData.refresh({LiveSource.tables, LiveSource.orders}, force: true));
      say(result.message);
      _draft.clear();
      navigator.pop();
    } on ApiException catch (e) {
      say(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _subtitle(TableModel? table) {
    if (table == null) return null;
    final order = table.currentOrderId != null ? MockData.findOrder(table.currentOrderId!) : null;
    final target = order != null ? 'thêm vào đơn #${order.displayCode}' : 'đơn mới';
    return '${table.area} · ${table.capacity} khách · $target';
  }

  @override
  Widget build(BuildContext context) {
    final foods = _filteredFoods;
    final table = _table;

    return PopScope(
      canPop: _draft.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Lấy navigator trước khi chờ hộp thoại để không dùng context sau await.
        final navigator = Navigator.of(context);
        final shouldDiscard = await _confirmDiscard();
        if (!shouldDiscard) return;
        _draft.clear();
        navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceAlt,
        body: Column(
          children: [
            AppHeaderBand(
              title: table != null ? 'Order · ${table.number}' : 'Tạo Order',
              subtitle: _subtitle(table),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: AppSearchBar(
                hint: 'Tìm món...',
                fillColor: AppColors.surface,
                onChanged: (v) => setState(() => _keyword = v),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      label: 'Tất cả',
                      selected: _selectedCategoryId == null,
                      onTap: () => setState(() => _selectedCategoryId = null),
                    ),
                  ),
                  for (final c in MockData.categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CategoryChip(
                        label: c.name,
                        selected: _selectedCategoryId == c.id,
                        onTap: () => setState(() => _selectedCategoryId = c.id),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildFoodList(foods)),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodList(List<Food> foods) {
    if (foods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Không tìm thấy món phù hợp',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (var i = 0; i < foods.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.border),
                FadeSlideIn.staggered(
                  index: i,
                  offsetY: 8,
                  child: foods[i].options.isEmpty
                      ? _FoodRow(
                          food: foods[i],
                          line: _lineOf(foods[i]),
                          onAdd: () => _addFood(foods[i]),
                          onQuantityChanged: (q) => _setQuantity(foods[i], q),
                          onEditNote: _editNote,
                        )
                      : _OptionFoodRow(
                          food: foods[i],
                          lines: _linesOf(foods[i]),
                          onAdd: () => _addFood(foods[i]),
                          onQuantityChanged: (line, q) => _draft.updateQuantity(line.id, q),
                          onEditNote: _editNote,
                        ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final empty = _draft.isEmpty;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      empty ? 'Chưa chọn món' : 'Tổng tiền · ${_draft.totalQuantity} món',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedValueText(
                        AppFormatters.currency(_draft.subtotal),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Gửi Order',
                  icon: Icons.near_me_outlined,
                  dense: true,
                  isLoading: _submitting,
                  onPressed: empty ? null : _submitOrder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog nhập ghi chú cho món (vd "ít cay", "không hành").
/// Dùng StatefulWidget để TextEditingController được tạo trong initState()
/// và huỷ trong dispose() đúng vòng đời — tránh lỗi "used after being disposed".
class _NoteDialog extends StatefulWidget {
  final String foodName;
  final String initialNote;

  const _NoteDialog({required this.foodName, required this.initialNote});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ghi chú: ${widget.foodName}'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 100,
        maxLines: 3,
        minLines: 2,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          hintText: 'Vd: ít cay, không hành...',
          counterText: '',
        ),
        onSubmitted: (_) => Navigator.pop(context, _ctrl.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, widget.initialNote),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

/// Một dòng món: tên, giá (và ghi chú khi đã chọn) bên trái; nút + hoặc bộ
/// − số + bên phải. Chạm vào dòng cũng thêm 1 phần cho nhanh.
class _FoodRow extends StatelessWidget {
  final Food food;
  final OrderItem? line;
  final VoidCallback onAdd;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<OrderItem> onEditNote;

  const _FoodRow({
    required this.food,
    required this.line,
    required this.onAdd,
    required this.onQuantityChanged,
    required this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
    final line = this.line;
    final quantity = line?.quantity ?? 0;

    return PressScale(
      onTap: onAdd,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(AppFormatters.currency(food.price),
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  // Ghi chú cho bếp (vd "ít cay") chỉ hiện với món đã chọn.
                  if (line != null) _NoteLink(note: line.note, onTap: () => onEditNote(line)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: quantity == 0
                  ? PressScale(
                      key: const ValueKey('add'),
                      onTap: onAdd,
                      scale: 0.85,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.add_rounded, size: 22, color: AppColors.textPrimary),
                      ),
                    )
                  : QuantityStepper(
                      key: const ValueKey('stepper'),
                      value: quantity,
                      min: 0,
                      size: QuantityStepperSize.large,
                      onChanged: onQuantityChanged,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteLink extends StatelessWidget {
  final String note;
  final VoidCallback onTap;

  const _NoteLink({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasNote = note.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note_rounded,
                size: 17, color: hasNote ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                hasNote ? note : 'Thêm ghi chú',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: hasNote ? FontWeight.w700 : FontWeight.w500,
                  color: hasNote ? AppColors.accent : AppColors.textSecondary,
                  decoration: hasNote ? null : TextDecoration.underline,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dòng món CÓ size/topping: tên + giá gốc và nút + (mở bảng chọn); bên dưới là từng dòng đã chọn
/// (vd "Size L, Trân châu · 45.000đ") với bộ − số + và ghi chú riêng.
class _OptionFoodRow extends StatelessWidget {
  final Food food;
  final List<OrderItem> lines;
  final VoidCallback onAdd;
  final void Function(OrderItem line, int quantity) onQuantityChanged;
  final ValueChanged<OrderItem> onEditNote;

  const _OptionFoodRow({
    required this.food,
    required this.lines,
    required this.onAdd,
    required this.onQuantityChanged,
    required this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressScale(
            onTap: onAdd,
            scale: 0.98,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        '${AppFormatters.currency(food.price)} · ${[
                          if (food.sizes.isNotEmpty) 'chọn size',
                          if (food.toppings.isNotEmpty) 'topping',
                        ].join(', ')}',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.add_rounded, size: 22, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          for (final line in lines)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.optionsLabel.isEmpty ? 'Không tùy chọn' : line.optionsLabel,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        Text(AppFormatters.currency(line.unitPrice),
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                        _NoteLink(note: line.note, onTap: () => onEditNote(line)),
                      ],
                    ),
                  ),
                  QuantityStepper(
                    value: line.quantity,
                    min: 0,
                    onChanged: (q) => onQuantityChanged(line, q),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bảng chọn size/topping cho một món. Cùng quy tắc với màn chi tiết món của khách:
/// size mặc định là size đầu tiên (chỉ chọn một), topping chọn thêm tùy ý.
/// Trả về danh sách tùy chọn đã chọn; đóng bảng thì trả về null.
class _OptionSheet extends StatefulWidget {
  final Food food;

  const _OptionSheet({required this.food});

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  late FoodOption? _size = widget.food.sizes.isNotEmpty ? widget.food.sizes.first : null;
  final Set<String> _toppingIds = {};

  List<FoodOption> get _selected => [
        if (_size != null) _size!,
        ...widget.food.toppings.where((t) => _toppingIds.contains(t.id)),
      ];

  double get _unitPrice => widget.food.price + _selected.fold(0.0, (sum, o) => sum + o.extraPrice);

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final label = TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(food.name,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                children: [
                  if (food.sizes.isNotEmpty) ...[
                    Text('Chọn size', style: label),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final size in food.sizes)
                          CategoryChip(
                            label: size.extraPrice > 0
                                ? '${size.name} (+${AppFormatters.currency(size.extraPrice)})'
                                : size.name,
                            selected: _size?.id == size.id,
                            onTap: () => setState(() => _size = size),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (food.toppings.isNotEmpty) ...[
                    Text('Chọn topping', style: label),
                    const SizedBox(height: 4),
                    for (final topping in food.toppings)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _toppingIds.contains(topping.id),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.primary,
                        checkColor: AppColors.textOnPrimary,
                        title: Text(topping.name, style: const TextStyle(fontSize: 14)),
                        secondary: Text('+${AppFormatters.currency(topping.extraPrice)}',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _toppingIds.add(topping.id);
                          } else {
                            _toppingIds.remove(topping.id);
                          }
                        }),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton(
                label: 'Thêm vào order · ${AppFormatters.currency(_unitPrice)}',
                onPressed: () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
