import 'dart:convert';

import 'package:dineflow/core/api/api_client.dart';
import 'package:dineflow/core/api/api_exception.dart';
import 'package:dineflow/core/session/session_store.dart';
import 'package:dineflow/data/app_data.dart';
import 'package:dineflow/data/cart_store.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/data/order_repository.dart';
import 'package:dineflow/data/table_repository.dart';
import 'package:dineflow/models/food_option.dart';
import 'package:dineflow/models/order.dart';
import 'package:dineflow/models/order_item.dart';
import 'package:dineflow/models/table_model.dart';
import 'package:dineflow/screens/order_staff/create_order_screen.dart';
import 'package:dineflow/screens/order_staff/serving_orders_screen.dart';
import 'package:dineflow/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Một đơn đúng định dạng backend trả về (`OrderResource`).
Map<String, Object?> _order(
  int id, {
  String status = 'placed',
  String payment = 'unpaid',
  Object? table = 'Bàn 1',
  Object? customer,
  Object? staff = 'Nguyễn Văn Order',
  List<Map<String, Object?>>? items,
}) =>
    {
      'id': id,
      'code': 'OD251008-${1000 + id}',
      'table_id': table == null ? null : 1,
      'table_number': table,
      'customer_id': customer == null ? null : 4,
      'customer_name': customer,
      'staff_id': staff == null ? null : 2,
      'staff_name': staff,
      'status': status,
      'status_label': 'x',
      'payment_status': payment,
      'note': null,
      'subtotal': 74000,
      'total_quantity': 2,
      'items': items ??
          [
            {
              'id': 1,
              'food_id': 1,
              'food_name': 'Cà phê sữa đá',
              'price': 29000,
              'quantity': 2,
              'options': [
                {'id': 2, 'group': 'size', 'name': 'Size M', 'price_modifier': 8000},
              ],
              'options_label': 'Size M',
              'note': 'Ít đá',
              'unit_price': 37000,
              'total': 74000,
            },
          ],
      'created_at': '2025-10-08T10:30:00+07:00',
    };

http.Response _json(int code, Object? data, {String status = 'success', String message = 'OK'}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode({'status': status, 'message': message, 'data': data})),
      code,
      headers: {'content-type': 'application/json'},
    );

OrderRepository _repo(Future<http.Response> Function(http.Request) handler) => OrderRepository(
      api: ApiClient(client: MockClient(handler), session: SessionStore(), baseUrl: 'http://test/api'),
    );

void main() {
  late OrderRepository originalRepo;
  late TableRepository originalTables;
  late List<Order> originalOrders;
  late List<TableModel> originalTableList;

  setUp(() {
    originalRepo = OrderRepository.instance;
    originalTables = TableRepository.instance;
    originalOrders = MockData.orders;
    originalTableList = MockData.tables;
  });

  tearDown(() {
    OrderRepository.instance = originalRepo;
    TableRepository.instance = originalTables;
    MockData.setOrders(originalOrders);
    MockData.setTables(originalTableList);
    AppCart.staffOrder.clear();
  });

  group('Order.fromApiJson', () {
    test('đọc đủ trường: mã đơn, bàn, món kèm tùy chọn, trạng thái, giờ tạo', () {
      final order = Order.fromApiJson(_order(12, status: 'preparing', payment: 'pending'));

      expect(order.id, '12');
      expect(order.code, 'OD251008-1012');
      expect(order.displayCode, 'OD251008-1012');
      expect(order.tableNumber, 'Bàn 1');
      expect(order.staffName, 'Nguyễn Văn Order');
      expect(order.status, OrderStatus.preparing);
      expect(order.paymentStatus, PaymentStatus.pending);
      expect(order.createdAt.toUtc(), DateTime.utc(2025, 10, 8, 3, 30));

      final item = order.items.single;
      expect(item.foodId, '1');
      expect(item.foodName, 'Cà phê sữa đá');
      expect(item.price, 29000); // đơn giá gốc, chưa gồm tùy chọn
      expect(item.selectedOptions.single.name, 'Size M');
      expect(item.selectedOptions.single.type, FoodOptionType.size);
      expect(item.note, 'Ít đá');
      expect(item.unitPrice, 37000);
      expect(order.subtotal, 74000); // tính lại từ món, khớp tổng server
      expect(order.totalQuantity, 2);
    });

    test('đơn khách tự đặt: không bàn, không nhân viên -> "Đặt qua app"', () {
      final order = Order.fromApiJson(_order(5, table: null, customer: 'Lê Minh Khách', staff: null));

      expect(order.tableNumber, isNull);
      expect(order.customerName, 'Lê Minh Khách');
      expect(order.staffName, 'Đặt qua app');
    });

    test('mã đơn mẫu (không có code) hiển thị bằng id viết hoa', () {
      expect(MockData.findOrder('ord1')!.displayCode, 'ORD1');
    });

    test('giá trị lạ không làm hỏng việc đọc: trạng thái mặc định', () {
      final order = Order.fromApiJson({..._order(9), 'status': 'khong_biet', 'payment_status': null});
      expect(order.status, OrderStatus.placed);
      expect(order.paymentStatus, PaymentStatus.unpaid);
    });
  });

  group('OrderRepository', () {
    test('fetchAll lấy 100 đơn mới nhất', () async {
      Uri? seen;
      final repo = _repo((req) async {
        seen = req.url;
        return _json(200, [_order(1), _order(2, status: 'completed', payment: 'paid')]);
      });

      final orders = await repo.fetchAll();

      expect(seen!.path, '/api/orders');
      expect(seen!.queryParameters['per_page'], '100');
      expect(orders.map((o) => o.id), ['1', '2']);
    });

    test('create gửi id số, tùy chọn và ghi chú; KHÔNG gửi giá', () async {
      late Map<String, dynamic> body;
      final repo = _repo((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/api/orders');
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(201, _order(12), message: 'Tạo đơn hàng thành công.');
      });

      final result = await repo.create(
        tableId: '3',
        note: '  Khách VIP ',
        items: const [
          OrderItem(
            id: 'x1',
            foodId: '1',
            foodName: 'Cà phê sữa đá',
            price: 29000,
            quantity: 2,
            selectedOptions: [
              FoodOption(id: '2', type: FoodOptionType.size, name: 'Size M', extraPrice: 8000)
            ],
            note: 'Ít đá',
          ),
          OrderItem(id: 'x2', foodId: '12', foodName: 'Gà cánh', price: 48000),
        ],
      );

      expect(body['table_id'], 3);
      expect(body['note'], 'Khách VIP');
      final items = (body['items'] as List).cast<Map<String, dynamic>>();
      expect(items[0], {
        'food_id': 1,
        'quantity': 2,
        'option_ids': [2],
        'note': 'Ít đá',
      });
      expect(items[1], {'food_id': 12, 'quantity': 1}); // không option, không note
      expect(body.toString(), isNot(contains('price')));

      expect(result.order.id, '12');
      expect(result.message, 'Tạo đơn hàng thành công.');
    });

    test('create với id không phải số (dữ liệu mẫu) báo lỗi dễ hiểu và KHÔNG gọi mạng', () async {
      var calls = 0;
      final repo = _repo((_) async {
        calls++;
        return _json(200, _order(1));
      });

      await expectLater(
        repo.create(
            tableId: '3', items: const [OrderItem(id: 'a', foodId: 'f1', foodName: 'Cà phê', price: 1)]),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Cà phê'))),
      );
      expect(calls, 0);
    });

    test('create bị server từ chối (món hết hàng) -> ApiException mang lời server', () async {
      final repo = _repo(
          (_) async => _json(422, null, status: 'error', message: 'Món "Tiramisu" hiện không phục vụ.'));

      await expectLater(
        repo.create(
            tableId: '1', items: const [OrderItem(id: 'a', foodId: '14', foodName: 'Tiramisu', price: 1)]),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('không phục vụ'))),
      );
    });

    test('updateStatus gọi PATCH /orders/{id}/status', () async {
      late http.Request seen;
      final repo = _repo((req) async {
        seen = req;
        return _json(200, _order(12, status: 'serving'));
      });

      final order = await repo.updateStatus('12', OrderStatus.serving);

      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/api/orders/12/status');
      expect(jsonDecode(seen.body), {'status': 'serving'});
      expect(order.status, OrderStatus.serving);
    });
  });

  group('AppData.refreshOrders', () {
    test('thay danh sách đơn và báo cho màn hình đang mở', () async {
      OrderRepository.instance = _repo((_) async => _json(200, [_order(1), _order(2)]));
      final before = MockData.ordersVersion.value;

      final error = await AppData.refreshOrders();

      expect(error, isNull);
      expect(MockData.orders.map((o) => o.id), ['1', '2']);
      expect(MockData.ordersVersion.value, before + 1);
    });

    test(
        'nhiều màn xin làm mới cùng lúc dùng chung một yêu cầu; force thì gửi lượt mới và chỉ lượt mới được áp dụng',
        () async {
      var requests = 0;
      OrderRepository.instance = _repo((_) async {
        final n = ++requests;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _json(200, [_order(n)]);
      });

      // Hai nơi cùng xin làm mới -> chỉ một yêu cầu đến server
      await Future.wait([AppData.refreshOrders(), AppData.refreshOrders()]);
      expect(requests, 1);
      expect(MockData.orders.single.id, '1');

      // Ngay sau khi đổi dữ liệu (vd. thanh toán) cần lượt tải mới, không dùng lại lượt đang chạy (có thể đã cũ)
      await Future.wait([AppData.refreshOrders(), AppData.refreshOrders(force: true)]);
      expect(requests, 3);
      expect(MockData.orders.single.id, '3'); // lượt cũ (2) về sau cũng không ghi đè lượt mới (3)
    });

    test('lỗi mạng: giữ nguyên đơn đang có và trả thông báo', () async {
      OrderRepository.instance = _repo((_) async => throw http.ClientException('offline'));

      final error = await AppData.refreshOrders();

      expect(error, startsWith('đơn hàng:'));
      expect(MockData.orders, same(originalOrders));
    });

    test('hóa đơn mẫu vẫn truy cập được dù đơn mẫu đã bị thay bằng đơn thật', () async {
      MockData.setOrders([Order.fromApiJson(_order(1))]);

      expect(MockData.invoices, isNotEmpty); // trước đây: StateError vì không còn đơn 'ord4'
    });
  });

  group('Giao diện nhân viên', () {
    void usePhoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('Đơn đang phục vụ: hiện đơn mở có bàn từ server, bỏ đơn đã xong / không bàn', (tester) async {
      usePhoneSize(tester);
      var payload = [
        _order(1, status: 'placed', table: 'Bàn 41'),
        _order(2, status: 'serving', table: 'Bàn 42'),
        _order(3, status: 'completed', payment: 'paid', table: 'Bàn 43'),
        _order(4, status: 'placed', table: null, customer: 'Khách', staff: null),
      ];
      OrderRepository.instance = _repo((_) async => _json(200, payload));
      TableRepository.instance = TableRepository(
        api: ApiClient(
            client: MockClient((_) async => _json(200, [])),
            session: SessionStore(),
            baseUrl: 'http://t/api'),
      );

      await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: const ServingOrdersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('2 đơn đang mở'), findsOneWidget);
      expect(find.textContaining('OD251008-1001 · Bàn 41'), findsOneWidget);
      expect(find.textContaining('OD251008-1002 · Bàn 42'), findsOneWidget);
      expect(find.textContaining('OD251008-1003'), findsNothing); // đã hoàn thành

      // Có đơn mới trên server -> kéo xuống để thấy.
      payload = [...payload, _order(7, status: 'preparing', table: 'Bàn 44')];
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('3 đơn đang mở'), findsOneWidget);
      expect(find.textContaining('OD251008-1007 · Bàn 44'), findsOneWidget);
    });

    Future<void> openCreateOrder(WidgetTester tester, String tableId) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.current,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => CreateOrderScreen(tableId: tableId))),
                child: const Text('mở order'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mở order'));
      await tester.pumpAndSettle();
    }

    testWidgets('Gửi Order: gửi đúng bàn + món lên server, thành công thì đóng màn và báo kết quả',
        (tester) async {
      usePhoneSize(tester);
      final calls = <({String? tableId, List<OrderItem> items})>[];
      OrderRepository.instance = _RecordingOrders(onCreate: (tableId, items) async {
        calls.add((tableId: tableId, items: items));
        return (order: Order.fromApiJson(_order(12)), message: 'Tạo đơn hàng thành công.');
      });

      final table = MockData.tables.first;
      await openCreateOrder(tester, table.id);

      await tester.tap(find.text('Cà phê sữa đá').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi Order'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.tableId, table.id);
      expect(calls.single.items.single.foodName, 'Cà phê sữa đá');
      expect(calls.single.items.single.quantity, 1);

      expect(find.byType(CreateOrderScreen), findsNothing); // đã đóng màn
      expect(find.text('Tạo đơn hàng thành công.'), findsOneWidget);
      expect(AppCart.staffOrder.isEmpty, isTrue);
    });

    testWidgets('Gửi Order bị server từ chối: ở lại màn, báo lỗi, GIỮ nguyên món đã chọn', (tester) async {
      usePhoneSize(tester);
      OrderRepository.instance = _RecordingOrders(
        onCreate: (_, __) async =>
            throw const ApiException('Món "Tiramisu" hiện không phục vụ.', statusCode: 422),
      );

      await openCreateOrder(tester, MockData.tables.first.id);
      await tester.tap(find.text('Cà phê sữa đá').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi Order'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateOrderScreen), findsOneWidget);
      expect(find.text('Món "Tiramisu" hiện không phục vụ.'), findsOneWidget);
      expect(AppCart.staffOrder.totalQuantity, 1);

      // Gửi lại được (nút không bị kẹt ở trạng thái đang gửi).
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Gửi Order')).onPressed,
          isNotNull);
    });
  });
}

/// OrderRepository giả cho test giao diện: chỉ `create` được ghi lại / giả lập; `fetchAll` trả đơn đang có.
class _RecordingOrders extends OrderRepository {
  _RecordingOrders({required this.onCreate})
      : super(
            api: ApiClient(
                client: MockClient((_) async => _json(200, [])),
                session: SessionStore(),
                baseUrl: 'http://t/api'));

  final Future<({Order order, String message})> Function(String? tableId, List<OrderItem> items) onCreate;

  @override
  Future<List<Order>> fetchAll() async => MockData.orders;

  @override
  Future<({Order order, String message})> create(
          {String? tableId, required List<OrderItem> items, String? note}) =>
      onCreate(tableId, items);
}
