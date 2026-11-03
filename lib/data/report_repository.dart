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
