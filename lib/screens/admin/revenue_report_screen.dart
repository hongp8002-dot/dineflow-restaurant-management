import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../data/app_data.dart';
import '../../data/mock_data.dart';
import '../../data/report_repository.dart';
import '../../models/revenue.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_button.dart';
import '../../widgets/live_data.dart';
import '../../widgets/mock_bar_chart.dart';
import '../../widgets/section_header.dart';

enum _ReportRange { day, week, month }

/// Báo cáo doanh thu: theo ngày/tuần/tháng hoặc khoảng ngày tùy chỉnh, top món bán chạy.
class RevenueReportScreen extends StatefulWidget {
  const RevenueReportScreen({super.key});

  @override
  State<RevenueReportScreen> createState() => _RevenueReportScreenState();
}

class _RevenueReportScreenState extends State<RevenueReportScreen> {
  _ReportRange _range = _ReportRange.day;

  /// Khoảng ngày tùy chỉnh, null = đang xem 7 ngày / 6 tuần / 6 tháng.
  DateTimeRange? _customRange;

  /// Doanh thu từng ngày của [_customRange], tải riêng từ server (`GET /reports/revenue`).
  List<RevenuePoint> _customPoints = const [];
  bool _customLoading = false;
  String? _customError;

  List<RevenuePoint> _data(ReportOverview report) {
    if (_customRange != null) return _customPoints;
    switch (_range) {
      case _ReportRange.day:
        return report.revenueByDay;
      case _ReportRange.week:
        return report.revenueByWeek;
      case _ReportRange.month:
        return report.revenueByMonth;
    }
  }

  /// Nhãn tiêu đề cho vùng biểu đồ (thay đổi theo chế độ đang chọn).
  String get _chartTitle {
    final custom = _customRange;
    if (custom != null) {
      return 'Doanh thu ${AppFormatters.date(custom.start)} – ${AppFormatters.date(custom.end)}';
    }
    switch (_range) {
      case _ReportRange.day:
        return 'Doanh thu 7 ngày gần đây';
      case _ReportRange.week:
        return 'Doanh thu 6 tuần gần đây';
      case _ReportRange.month:
        return 'Doanh thu 6 tháng gần đây';
    }
  }

  /// Mở bộ chọn khoảng ngày; chọn xong thì tải doanh thu từng ngày của khoảng đó.
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      helpText: 'Chọn khoảng ngày (tối đa 31 ngày)',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.textOnPrimary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _customRange = picked);
    await _loadCustomRange();
  }

  Future<void> _loadCustomRange() async {
    final range = _customRange;
    if (range == null) return;
    setState(() {
      _customLoading = true;
      _customError = null;
    });
    try {
      final points = await ReportRepository.instance.fetchRevenueRange(range.start, range.end);
      if (!mounted || range != _customRange) return;
      setState(() => _customPoints = points);
    } on ApiException catch (e) {
      if (!mounted || range != _customRange) return;
      setState(() {
        _customPoints = const [];
        _customError = e.message;
      });
    } finally {
      if (mounted && range == _customRange) setState(() => _customLoading = false);
    }
  }

  void _clearCustomRange() => setState(() {
        _customRange = null;
        _customPoints = const [];
        _customError = null;
        _customLoading = false;
      });

  /// Kéo để làm mới: tải lại báo cáo tổng quan, và cả khoảng ngày tùy chỉnh nếu đang xem.
  Future<void> _refreshAll(Future<void> Function() refresh) async {
    await Future.wait([refresh(), if (_customRange != null) _loadCustomRange()]);
  }

  /// Số liệu lấy từ báo cáo của server, tự tải mới khi mở màn và khi kéo để làm mới.
  @override
  Widget build(BuildContext context) => LiveData(
        sources: const {LiveSource.report},
        builder: _buildContent,
      );

  Widget _buildContent(BuildContext context, Future<void> Function() refresh) {
    final report = MockData.report;
    final data = _data(report);
    final totalRevenue = data.fold<double>(0, (sum, p) => sum + p.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo doanh thu'),
        actions: [
          TextButton.icon(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const _ExportSheet(),
            ),
            icon: Icon(Icons.file_download_outlined, color: AppColors.textPrimary),
            label: Text('Xuất Excel', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _refreshAll(refresh),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              // ── Bộ lọc: 7 ngày / 6 tuần / 6 tháng + nút chọn khoảng ngày ─────────
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_ReportRange>(
                    segments: const [
                      ButtonSegment(value: _ReportRange.day, label: Text('7 ngày')),
                      ButtonSegment(value: _ReportRange.week, label: Text('6 tuần')),
                      ButtonSegment(value: _ReportRange.month, label: Text('6 tháng')),
                    ],
                    selected: {_range},
                    onSelectionChanged: (s) {
                      _clearCustomRange(); // chọn mốc có sẵn thì bỏ khoảng tùy chỉnh
                      setState(() => _range = s.first);
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected) ? AppColors.primary : AppColors.surface),
                      foregroundColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected)
                              ? AppColors.textOnPrimary
                              : AppColors.textPrimary),
                      textStyle:
                          const WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Chọn khoảng ngày',
                    child: InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 42,
                        width: 42,
                        decoration: BoxDecoration(
                          color: _customRange != null ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _customRange != null ? AppColors.primary : AppColors.border),
                        ),
                        child: Icon(
                          Icons.calendar_month_outlined,
                          size: 20,
                          color: _customRange != null ? AppColors.textOnPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // ── Chip khoảng ngày đang xem (bấm × để bỏ) ─────────────────────
              if (_customRange != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${AppFormatters.date(_customRange!.start)} – ${AppFormatters.date(_customRange!.end)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _clearCustomRange,
                            child: Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tổng doanh thu', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    // Đổi khoảng thời gian: số tổng và biểu đồ chuyển mượt thay vì nhảy.
                    AnimatedValueText(
                      AppFormatters.currency(totalRevenue),
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(_chartTitle, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    if (_customRange != null && _customLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_customRange != null && _customError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(_customError!, style: TextStyle(fontSize: 13, color: AppColors.error)),
                      )
                    else
                      AnimatedSwitcher(
                        duration: AppMotion.normal,
                        child: MockBarChart(key: ValueKey('$_range-${_customRange?.start}-${_customRange?.end}'), data: data),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionHeader(title: 'Món bán chạy · ${report.topFoodsDays} ngày'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < report.topFoods.length; i++) ...[
                      FadeSlideIn.staggered(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: AppColors.textPrimary)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(report.topFoods[i].foodName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                                    Text('Đã bán ${report.topFoods[i].soldQuantity}',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Text(AppFormatters.currency(report.topFoods[i].revenue),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                      if (i != report.topFoods.length - 1) const Divider(height: 1),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng xuất báo cáo Excel: chọn Ngày / Tháng / Năm (cùng lựa chọn với nút Xuất trên web /admin).
/// Tháng và năm chỉ liệt kê những kỳ đã có doanh thu (server tính). Bấm tải → server trả link có
/// chữ ký 5 phút → mở bằng trình duyệt để tải file .xlsx (không cần thư viện lưu file).
class _ExportSheet extends StatefulWidget {
  const _ExportSheet();

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  String _type = 'month';
  DateTime _day = DateTime.now();
  String? _month;
  String? _year;

  ExportPeriods? _periods;
  String? _error;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    try {
      final periods = await ReportRepository.instance.fetchExportPeriods();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _month = periods.months.isNotEmpty ? periods.months.first.value : null;
        _year = periods.years.isNotEmpty ? periods.years.first.value : null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String? get _value => switch (_type) {
        'day' => '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}',
        'month' => _month,
        _ => _year,
      };

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Chọn ngày xuất báo cáo',
    );
    if (picked != null && mounted) setState(() => _day = picked);
  }

  Future<void> _download() async {
    final value = _value;
    if (value == null || _downloading) return;
    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final link = await ReportRepository.instance.createExportLink(_type, value);
      final opened = await launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
      if (!opened) throw const ApiException('Không mở được trình duyệt để tải file.');
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Đang tải báo cáo ${link.label} bằng trình duyệt…')));
    } on ApiException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periods = _periods;
    final label = TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary);
    final options = _type == 'month' ? periods?.months : periods?.years;

    Widget body;
    if (_error != null) {
      body = Text(_error!, style: TextStyle(color: AppColors.error));
    } else if (periods == null) {
      body = const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Xuất theo', style: label),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'day', label: Text('Ngày')),
              ButtonSegment(value: 'month', label: Text('Tháng')),
              ButtonSegment(value: 'year', label: Text('Năm')),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          if (_type == 'day')
            OutlinedButton.icon(
              onPressed: _pickDay,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(AppFormatters.date(_day)),
            )
          else if (options == null || options.isEmpty)
            Text('Chưa có doanh thu để xuất.', style: TextStyle(color: AppColors.textSecondary))
          else
            DropdownButtonFormField<String>(
              value: _type == 'month' ? _month : _year,
              decoration: InputDecoration(
                labelText: _type == 'month' ? 'Tháng có doanh thu' : 'Năm có doanh thu',
              ),
              items: [for (final o in options) DropdownMenuItem(value: o.value, child: Text(o.label))],
              onChanged: (v) => setState(() {
                if (_type == 'month') {
                  _month = v;
                } else {
                  _year = v;
                }
              }),
            ),
          const SizedBox(height: 8),
          Text(
            _type == 'year'
                ? 'File gồm: Hóa đơn, Doanh thu theo ngày, Doanh thu theo tháng, Món bán chạy.'
                : 'File gồm: Hóa đơn, Doanh thu theo ngày, Món bán chạy.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Tải file Excel',
            icon: Icons.file_download_outlined,
            isLoading: _downloading,
            onPressed: _value == null ? null : _download,
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Xuất báo cáo Excel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            body,
          ],
        ),
      ),
    );
  }
}
