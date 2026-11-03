import 'dart:convert';

import 'package:dineflow/core/api/api_client.dart';
import 'package:dineflow/core/session/session_store.dart';
import 'package:dineflow/data/app_data.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/data/table_repository.dart';
import 'package:dineflow/models/customer.dart';
import 'package:dineflow/models/table_model.dart';
import 'package:dineflow/screens/order_staff/table_management_screen.dart';
import 'package:dineflow/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _table(int id, String number, String area, {String status = 'empty', Object? order}) => {
      'id': id,
      'number': number,
      'area': area,
      'capacity': 4,
      'status': status,
      'serving_since': status == 'serving' ? '2025-01-31T10:30:00+07:00' : null,
      'current_order_id': order,
      'next_reservation_at': null,
    };

http.Response _ok(Object data) => http.Response.bytes(
      utf8.encode(jsonEncode({'status': 'success', 'message': 'OK', 'data': data})),
      200,
      headers: {'content-type': 'application/json'},
    );

TableRepository _repoReturning(Object? Function() payload) => TableRepository(
      api: ApiClient(
        client: MockClient((_) async => _ok(payload()!)),
        session: SessionStore(),
        baseUrl: 'http://test/api',
      ),
    );

void main() {
  late TableRepository originalRepo;
  late List<TableModel> originalTables;

  setUp(() {
    originalRepo = TableRepository.instance;
    originalTables = MockData.tables;
  });

  tearDown(() async {
    TableRepository.instance = originalRepo;
    MockData.setTables(originalTables);
    await SessionStore.instance.clear();
  });

  group('TableModel.fromApiJson', () {
    test('đọc trạng thái, giờ bắt đầu phục vụ (đổi sang giờ máy) và đơn hiện tại', () {
      final serving = TableModel.fromApiJson(_table(2, 'Bàn 2', 'Tầng 1', status: 'serving', order: 12));

      expect(serving.id, '2');
      expect(serving.status, TableStatus.serving);
      expect(serving.currentOrderId, '12');
      expect(serving.servingSince!.toUtc(), DateTime.utc(2025, 1, 31, 3, 30));
      expect(serving.servingSince!.isUtc, isFalse);

      final reserved = TableModel.fromApiJson(_table(3, 'Bàn 3', 'Tầng 1', status: 'reserved'));
      expect(reserved.status, TableStatus.reserved);
      expect(reserved.servingSince, isNull);
      expect(reserved.currentOrderId, isNull);

      expect(TableModel.fromApiJson(_table(4, 'Bàn 4', 'Tầng 1')).status, TableStatus.empty);
    });
  });

  group('AppData.refreshTables', () {
    test('thay danh sách bàn, giữ thứ tự khu vực theo server và báo cho màn hình đang mở', () async {
      TableRepository.instance = _repoReturning(() => [
            _table(1, 'Bàn 1', 'Tầng 1'),
            _table(2, 'Bàn 2', 'Tầng 2', status: 'serving', order: 7),
            _table(3, 'Bàn 3', 'Ngoài trời'),
          ]);
      final before = MockData.tablesVersion.value;

      final error = await AppData.refreshTables();

      expect(error, isNull);
      expect(MockData.tables.map((t) => t.number), ['Bàn 1', 'Bàn 2', 'Bàn 3']);
      expect(MockData.areas, ['Tầng 1', 'Tầng 2', 'Ngoài trời']);
      expect(MockData.tablesVersion.value, before + 1);
    });

    test('lỗi mạng: trả thông báo, giữ nguyên bàn đang có và không báo thay đổi', () async {
      TableRepository.instance = TableRepository(
        api: ApiClient(
          client: MockClient((_) async => throw http.ClientException('offline')),
          session: SessionStore(),
          baseUrl: 'http://test/api',
        ),
      );
      final before = MockData.tablesVersion.value;

      final error = await AppData.refreshTables();

      expect(error, startsWith('bàn:'));
      expect(MockData.tables, same(originalTables));
      expect(MockData.tablesVersion.value, before);
    });
  });

  group('MockData dùng người đăng nhập thật', () {
    Future<void> signIn(String role, {String name = 'Tên Thật', int points = 0}) =>
        SessionStore.instance.save('tok', {
          'id': 77,
          'name': name,
          'email': 'x@x.com',
          'phone': '0911111111',
          'role': role,
          'status': 'active',
          'member_code': 'DF-MB0077',
          'points': points,
        });

    test('chưa đăng nhập: dùng tài khoản mẫu', () {
      expect(MockData.currentCashier, same(MockData.users[2]));
      expect(MockData.currentCustomer, same(MockData.customers[0]));
    });

    test('tên hiển thị là của người đăng nhập, chỉ khi đúng vai trò', () async {
      await signIn('cashier', name: 'Thu Ngân Thật');

      expect(MockData.currentCashier.name, 'Thu Ngân Thật');
      expect(MockData.currentOrderStaff, same(MockData.users[1])); // vai trò khác -> vẫn là mẫu
    });

    test('hồ sơ khách lấy mã thành viên và điểm từ server, hạng tính theo điểm', () async {
      await signIn('customer', points: 220);
      expect(MockData.currentCustomer.tier, MemberTier.silver);

      await signIn('customer', points: 850);
      expect(MockData.currentCustomer.tier, MemberTier.gold);
      expect(MockData.currentCustomer.memberCode, 'DF-MB0077');
      expect(MockData.currentCustomer.points, 850);

      await signIn('customer', points: 2100);
      expect(MockData.currentCustomer.tier, MemberTier.platinum);
    });
  });

  testWidgets('Sơ đồ bàn (nhân viên): hiện bàn từ server và cập nhật khi kéo để làm mới', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var serverTables = <Map<String, Object?>>[
      _table(1, 'Bàn 41', 'Tầng 1'),
      _table(2, 'Bàn 42', 'Tầng 1', status: 'serving', order: 9),
    ];
    var requests = 0;
    TableRepository.instance = TableRepository(
      api: ApiClient(
        client: MockClient((_) async {
          requests++;
          return _ok(serverTables);
        }),
        session: SessionStore(),
        baseUrl: 'http://test/api',
      ),
    );

    await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: const TableManagementScreen()));
    await tester.pumpAndSettle();

    // Mở màn hình là tự tải bàn mới nhất từ server (thay cho bàn mẫu).
    expect(requests, 1);
    // Ô bàn hiện mã hai chữ số của tên bàn ("Bàn 41" -> "41"); bàn mẫu "Bàn 1" ("01") không còn.
    expect(find.text('41'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('01'), findsNothing);

    // Server đổi dữ liệu; kéo xuống để làm mới.
    serverTables = [_table(1, 'Bàn 41', 'Tầng 1'), _table(5, 'Bàn 55', 'Tầng 2')];
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.text('55'), findsOneWidget);
    expect(find.text('42'), findsNothing);
  });
}
