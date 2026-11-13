import '../core/api/api_client.dart';
import '../models/revenue.dart';

/// Báo cáo doanh thu cho Admin.
class ReportRepository {
  ReportRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  /// Không phải `final` để test thay bằng bản giả.
  static ReportRepository instance = ReportRepository();

  final ApiClient _api;

  Future<ReportOverview> fetchOverview() async {
    final res = await _api.get('/reports/overview');
    return ReportOverview.fromApiJson(res.map);
  }

  /// Các kỳ xuất Excel: tháng / năm ĐÃ CÓ doanh thu (server tính theo giờ quán), mới nhất trước.
  Future<ExportPeriods> fetchExportPeriods() async {
    final res = await _api.get('/reports/export-periods');
    List<({String value, String label})> list(String key) => [
          for (final p in (res.map[key] as List<dynamic>).cast<Map<String, dynamic>>())
            (value: p['value'] as String, label: p['label'] as String),
        ];
    return ExportPeriods(months: list('months'), years: list('years'));
  }

  /// Xin link tải file Excel cho một kỳ. [type]: `day` (value `yyyy-MM-dd`), `month` (`yyyy-MM`),
  /// `year` (`yyyy`). Link có chữ ký, hết hạn sau 5 phút; mở bằng trình duyệt để tải file.
  Future<({String url, String label})> createExportLink(String type, String value) async {
    final res = await _api.post('/reports/export-link', body: {'type': type, 'value': value});
    return (url: res.map['url'] as String, label: res.map['label'] as String);
  }

  /// Doanh thu từng ngày trong khoảng ngày tùy chỉnh (tối đa 31 ngày, server kiểm tra).
  Future<List<RevenuePoint>> fetchRevenueRange(DateTime from, DateTime to) async {
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await _api.get('/reports/revenue', query: {'from': day(from), 'to': day(to)});
    return [
      for (final p in (res.map['revenue_by_day'] as List<dynamic>).cast<Map<String, dynamic>>())
        RevenuePoint.fromApiJson(p),
    ];
  }
}

/// Các tháng / năm có doanh thu để chọn khi xuất Excel.
class ExportPeriods {
  final List<({String value, String label})> months;
  final List<({String value, String label})> years;

  const ExportPeriods({required this.months, required this.years});
}
