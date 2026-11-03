import 'dart:convert';

import 'package:dineflow/core/api/api_client.dart';
import 'package:dineflow/core/api/api_exception.dart';
import 'package:dineflow/core/session/session_store.dart';
import 'package:dineflow/data/app_data.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/data/report_repository.dart';
import 'package:dineflow/models/revenue.dart';
import 'package:dineflow/screens/admin/admin_dashboard_screen.dart';
import 'package:dineflow/screens/admin/revenue_report_screen.dart';
import 'package:dineflow/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _reportJson({
  num today = 800000,
  num yesterday = 500000,
  num week = 3000000,
  num lastWeek = 0,
  List<Map<String, Object?>>? topFoods,
}) =>
    {
      'today_revenue': today,
      'yesterday_revenue': yesterday,
      'week_revenue': week,
      'last_week_revenue': lastWeek,
      'today_orders': 12,
      'today_members': 3,
      'revenue_by_day': [
        for (final (i, l) in ['T4', 'T5', 'T6', 'T7', 'CN', 'T2', 'T3'].indexed)
          {'label': l, 'amount': 100000 * (i + 1)},
      ],
      'revenue_by_week': [
        for (final l in ['01/09', '08/09', '15/09', '22/09', '29/09', '06/10'])
          {'label': l, 'amount': 2000000},
      ],
      'revenue_by_month': [
        for (final l in ['T5', 'T6', 'T7', 'T8', 'T9', 'T10']) {'label': l, 'amount': 9000000},
      ],
      'top_foods_days': 30,
      'top_foods': topFoods ??
          [
            {'food_name': 'Trà đào cam sả', 'sold_quantity': 9, 'revenue': 351000},
            {'food_name': 'Cà phê sữa đá', 'sold_quantity': 4, 'revenue': 148000},
          ],
    };

http.Response _json(int code, Object? data, {String status = 'success'}) => http.Response.bytes(
      utf8.encode(jsonEncode({'status': status, 'message': 'OK', 'data': data})),
      code,
      headers: {'content-type': 'application/json'},
    );

ReportRepository _repo(Future<http.Response> Function(http.Request) handler) => ReportRepository(
      api: ApiClient(client: MockClient(handler), session: SessionStore(), baseUrl: 'http://test/api'),
    );

void main() {
  tearDown(() => MockData.report = ReportOverview.empty);

  group('ReportRepository', () {
    test('đọc doanh thu theo khoảng ngày từ /reports/revenue', () async {
      late http.Request sent;
      final points = await _repo((req) async {
        sent = req;
        return _json(200, {
          'from': '2026-10-01',
          'to': '2026-10-03',
          'total': 600000,
          'revenue_by_day': [
            {'label': '01/10', 'amount': 100000},
            {'label': '02/10', 'amount': 200000},
            {'label': '03/10', 'amount': 300000},
          ],
        });
      }).fetchRevenueRange(DateTime(2026, 10, 1), DateTime(2026, 10, 3, 18, 30));

      expect(sent.url.path, '/api/reports/revenue');
      // Gửi ngày dạng yyyy-MM-dd, bỏ phần giờ.
      expect(sent.url.queryParameters, {'from': '2026-10-01', 'to': '2026-10-03'});
      expect(points.map((p) => p.label), ['01/10', '02/10', '03/10']);
      expect(points.last.amount, 300000);
    });

    test('khoảng ngày quá 31 ngày: báo lỗi của server', () async {
      await expectLater(
        () => _repo((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({'status': 'error', 'message': 'Chỉ xem được tối đa 31 ngày mỗi lần.', 'data': null})),
              422,
              headers: {'content-type': 'application/json'},
            )).fetchRevenueRange(DateTime(2026, 8, 1), DateTime(2026, 10, 1)),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Chỉ xem được tối đa 31 ngày mỗi lần.')),
      );
    });

    test('đọc báo cáo từ /reports/overview', () async {
      late http.Request sent;
      final report = await _repo((req) async {
        sent = req;
        return _json(200, _reportJson());
      }).fetchOverview();

      expect(sent.method, 'GET');
      expect(sent.url.path, '/api/reports/overview');
      expect(report.todayRevenue, 800000);
      expect(report.todayOrders, 12);
      expect(report.todayMembers, 3);
      expect(report.revenueByDay.map((p) => p.label), ['T4', 'T5', 'T6', 'T7', 'CN', 'T2', 'T3']);
      expect(report.revenueByDay.last.amount, 700000);
      expect(report.revenueByWeek, hasLength(6));
      expect(report.revenueByMonth, hasLength(6));
      expect(report.topFoods.first.foodName, 'Trà đào cam sả');
      expect(report.topFoods.first.soldQuantity, 9);
      expect(report.topFoodsDays, 30);
    });

    test('không phải admin (403) thì ném ApiException kèm lý do', () async {
      final repo = _repo((_) async => _json(403, null, status: 'error'));
      expect(repo.fetchOverview(), throwsA(isA<ApiException>()));
    });

    test('changePercent: làm tròn, và null khi kỳ trước bằng 0', () {
      expect(ReportOverview.changePercent(150, 100), 50);
      expect(ReportOverview.changePercent(80, 100), -20);
      expect(ReportOverview.changePercent(100, 0), isNull);
    });
  });

  group('AppData', () {
    test('refreshReport đưa số liệu vào MockData.report', () async {
      final before = MockData.reportVersion.value;
      ReportRepository.instance = _repo((_) async => _json(200, _reportJson(today: 123000)));

      expect(await AppData.refreshReport(force: true), isNull);

      expect(MockData.report.todayRevenue, 123000);
      expect(MockData.reportVersion.value, greaterThan(before));
    });

    test('lỗi mạng: giữ số liệu cũ và báo lỗi', () async {
      MockData.report = ReportOverview.fromApiJson(_reportJson(today: 5000));
      ReportRepository.instance = _repo((_) async => _json(500, null, status: 'error'));

      final error = await AppData.refreshReport(force: true);

      expect(error, startsWith('báo cáo:'));
      expect(MockData.report.todayRevenue, 5000);
    });
  });

  group('Màn hình Admin hiển thị số liệu thật', () {
    Future<void> pump(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = const Size(360, 900) * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: screen));
      await tester.pumpAndSettle();
    }

    testWidgets('Dashboard: doanh thu, xu hướng, món bán chạy', (tester) async {
      MockData.report = ReportOverview.fromApiJson(_reportJson());
      await pump(tester, const AdminDashboardScreen());

      expect(find.textContaining('800.000'), findsOneWidget); // doanh thu hôm nay
      expect(find.text('+60% so với hôm qua'), findsOneWidget); // (800k-500k)/500k
      // Tuần trước chưa có doanh thu -> không có phần trăm để so
      expect(find.textContaining('so với tuần trước'), findsNothing);
      expect(find.text('Trà đào cam sả'), findsOneWidget);
      expect(find.text('9 đã bán'), findsOneWidget);
      expect(find.text('Món bán chạy · 30 ngày'), findsOneWidget);
    });

    testWidgets('Dashboard: doanh thu giảm thì hiện số âm', (tester) async {
      MockData.report = ReportOverview.fromApiJson(_reportJson(today: 250000, yesterday: 500000));
      await pump(tester, const AdminDashboardScreen());

      expect(find.text('-50% so với hôm qua'), findsOneWidget);
    });

    testWidgets('Dashboard: chưa có dữ liệu thì không vỡ giao diện', (tester) async {
      await pump(tester, const AdminDashboardScreen());

      expect(tester.takeException(), isNull);
      expect(find.text('Chưa có dữ liệu món bán chạy'), findsOneWidget);
    });

    testWidgets('Báo cáo doanh thu: đổi khoảng thời gian đổi tổng và nhãn biểu đồ', (tester) async {
      MockData.report = ReportOverview.fromApiJson(_reportJson());
      await pump(tester, const RevenueReportScreen());

      // 7 ngày: 100k + 200k + ... + 700k = 2.800.000
      expect(find.textContaining('2.800.000'), findsOneWidget);
      expect(find.text('CN'), findsOneWidget);

      await tester.tap(find.text('6 tuần'));
      await tester.pumpAndSettle();
      expect(find.textContaining('12.000.000'), findsOneWidget); // 6 x 2 triệu
      expect(find.text('29/09'), findsOneWidget);

      await tester.tap(find.text('6 tháng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('54.000.000'), findsOneWidget); // 6 x 9 triệu
      expect(find.text('T10'), findsOneWidget);

      expect(find.text('Cà phê sữa đá'), findsOneWidget);
    });
  });
}
