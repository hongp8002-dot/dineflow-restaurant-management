import 'dart:convert';

import 'package:dineflow/app/routes.dart';
import 'package:dineflow/core/api/api_client.dart';
import 'package:dineflow/core/api/api_exception.dart';
import 'package:dineflow/core/session/session_store.dart';
import 'package:dineflow/data/app_data.dart';
import 'package:dineflow/data/invoice_repository.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/models/invoice.dart';
import 'package:dineflow/models/order.dart';
import 'package:dineflow/models/promotion.dart';
import 'package:dineflow/screens/cashier/history_screen.dart';
import 'package:dineflow/screens/cashier/payment_screen.dart';
import 'package:dineflow/theme/app_theme.dart';
import 'package:dineflow/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _utc = 'Z';

String _iso(DateTime time) => '${time.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), '')}$_utc';

Map<String, Object?> _orderJson(
  int id, {
  String status = 'serving',
  String payment = 'unpaid',
  Object? table = 'Bàn 1',
  String? customer,
  int points = 0,
  DateTime? createdAt,
}) =>
    {
      'id': id,
      'code': 'OD251008-${1000 + id}',
      'table_number': table,
      'customer_name': customer,
      'customer_points': customer == null ? null : points,
      'staff_name': 'Nguyễn Văn Order',
      'status': status,
      'payment_status': payment,
      'note': null,
      'created_at': _iso(createdAt ?? DateTime.now()),
      'items': [
        {
          'id': 1,
          'food_id': 1,
          'food_name': 'Cà phê sữa đá',
          'price': 29000,
          'quantity': 2,
          'options': [
            {'id': 2, 'group': 'size', 'name': 'Size M', 'price_modifier': 8000},
          ],
          'note': null,
        },
      ],
    };

Map<String, Object?> _invoiceJson(
  int id, {
  num subtotal = 74000,
  num discount = 7700,
  num total = 66300,
  String method = 'qr',
  int cashierId = 3,
  String cashierName = 'Trần Thị Thu Ngân',
  DateTime? paidAt,
}) =>
    {
      'id': id,
      'code': 'HD${id.toString().padLeft(5, '0')}',
      'order_id': 12,
      'order_code': 'OD251008-1012',
      'table_number': 'Bàn 1',
      'items': (_orderJson(12)['items']),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'promotion_code': 'WELCOME10',
      'payment_method': method,
      'status': 'paid',
      'created_at': _iso(paidAt ?? DateTime.now()),
      'cashier_id': cashierId,
      'cashier_name': cashierName,
    };

Map<String, Object?> _promoJson(
  int id,
  String code,
  int percent, {
  num? max,
  num min = 0,
}) =>
    {
      'id': id,
      'code': code,
      'title': 'Voucher $code',
      'description': null,
      'discount_percent': percent,
      'max_discount': max,
      'min_order_amount': min,
      'valid_from': _iso(DateTime.now().subtract(const Duration(days: 1))),
      'valid_to': _iso(DateTime.now().add(const Duration(days: 30))),
      'is_active': true,
      'status': 'active',
    };

http.Response _json(int code, Object? data, {String status = 'success', String message = 'OK'}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode({'status': status, 'message': message, 'data': data})),
      code,
      headers: {'content-type': 'application/json'},
    );

InvoiceRepository _repo(Future<http.Response> Function(http.Request) handler) => InvoiceRepository(
      api: ApiClient(client: MockClient(handler), session: SessionStore(), baseUrl: 'http://test/api'),
    );

/// InvoiceRepository giả cho test giao diện / AppData.
class _FakeInvoices extends InvoiceRepository {
  _FakeInvoices({this.onPay, this.list = const [], this.promos = const []})
      : super(
          api: ApiClient(
            client: MockClient((_) async => http.Response('{}', 200)),
            session: SessionStore(),
            baseUrl: 'http://t/api',
          ),
        );

  final Future<Invoice> Function(String orderId, PaymentMethod method, String? code, int points)? onPay;
  final List<Invoice> list;
  final List<Promotion> promos;
  int fetchAllCalls = 0;
  int promoCalls = 0;

  @override
  Future<List<Invoice>> fetchAll() async {
    fetchAllCalls++;
    return list;
  }

  @override
  Future<List<Promotion>> fetchAvailablePromotions() async {
    promoCalls++;
    return promos;
  }

  @override
  Future<Invoice> pay(String orderId,
          {required PaymentMethod method, String? promotionCode, String? memberCode, int pointsUsed = 0}) =>
      onPay!(orderId, method, promotionCode, pointsUsed);
}

Future<void> _signInAs(String role, {int id = 3}) => SessionStore.instance.save('tok', {
      'id': id,
      'name': 'Người Thật',
      'email': 'x@x.com',
      'phone': '0900000000',
      'role': role,
      'status': 'active',
    });

void main() {
  late InvoiceRepository originalRepo;
  late List<Order> originalOrders;
  late List<Invoice> originalInvoices;
  late List<Promotion> originalPromos;
  late List<Promotion> originalAllPromos;

  setUp(() {
    originalRepo = InvoiceRepository.instance;
    originalOrders = MockData.orders;
    originalInvoices = MockData.invoices;
    originalPromos = MockData.availablePromotions;
    originalAllPromos = MockData.promotions;
  });

  tearDown(() async {
    InvoiceRepository.instance = originalRepo;
    MockData.setOrders(originalOrders);
    MockData.setInvoices(originalInvoices);
    MockData.availablePromotions = originalPromos;
    MockData.promotions = originalAllPromos;
    await SessionStore.instance.clear();
  });

  group('Promotion', () {
    test('fromApiJson đọc đủ trường', () {
      final p = Promotion.fromApiJson(_promoJson(1, 'WELCOME10', 10, max: 30000, min: 50000));

      expect(p.id, '1');
      expect(p.code, 'WELCOME10');
      expect(p.name, 'Voucher WELCOME10');
      expect(p.percent, 10);
      expect(p.maxDiscount, 30000);
      expect(p.minOrderAmount, 50000);
      expect(p.status, PromotionStatus.active);
      expect(p.endDate.isAfter(p.startDate), isTrue);
    });

    test('discountFor tính giống server: làm tròn, áp trần, đơn tối thiểu', () {
      final capped = Promotion.fromApiJson(_promoJson(1, 'WELCOME10', 10, max: 30000));
      expect(capped.discountFor(74000), 7400);
      expect(capped.discountFor(500000), 30000); // 10% = 50.000 nhưng trần 30.000

      final uncapped = Promotion.fromApiJson(_promoJson(2, 'FREE20', 20));
      expect(uncapped.discountFor(500000), 100000);
      expect(uncapped.maxDiscount, isNull);

      final tenth = Promotion.fromApiJson(_promoJson(3, 'R10', 10));
      expect(tenth.discountFor(33333), 3333); // 3333,3
      expect(tenth.discountFor(33335), 3334); // 3333,5 làm tròn lên như PHP round()

      final withMin = Promotion.fromApiJson(_promoJson(4, 'COMBO15', 15, min: 200000));
      expect(withMin.appliesTo(199999), isFalse);
      expect(withMin.discountFor(199999), 0);
      expect(withMin.appliesTo(200000), isTrue);
      expect(withMin.discountFor(200000), 30000);
    });
  });

  group('Invoice.fromApiJson', () {
    test('đọc hóa đơn từ server', () {
      final invoice = Invoice.fromApiJson(_invoiceJson(7));

      expect(invoice.id, '7');
      expect(invoice.displayCode, 'HD00007');
      expect(invoice.displayOrderCode, 'OD251008-1012');
      expect(invoice.tableNumber, 'Bàn 1');
      expect(invoice.subtotal, 74000);
      expect(invoice.discount, 7700);
      expect(invoice.total, 66300);
      expect(invoice.paymentMethod, PaymentMethod.qr);
      expect(invoice.cashierName, 'Trần Thị Thu Ngân');
      expect(invoice.cashierId, '3');
      expect(invoice.items.single.selectedOptions.single.name, 'Size M');
      expect(invoice.items.single.unitPrice, 37000);
    });

    test('hóa đơn mẫu (không có mã server) hiển thị bằng id viết hoa', () {
      expect(MockData.invoices.first.displayCode, MockData.invoices.first.id.toUpperCase());
    });
  });

  group('InvoiceRepository', () {
    test('fetchAll lấy 100 hóa đơn gần nhất', () async {
      Uri? seen;
      final repo = _repo((req) async {
        seen = req.url;
        return _json(200, [_invoiceJson(2), _invoiceJson(1)]);
      });

      final invoices = await repo.fetchAll();

      expect(seen!.path, '/api/invoices');
      expect(seen!.queryParameters['per_page'], '100');
      expect(invoices.map((i) => i.id), ['2', '1']);
    });

    test('pay gửi phương thức, voucher và điểm; chỉ gửi trường nào có dùng', () async {
      final bodies = <Map<String, dynamic>>[];
      final paths = <String>[];
      final repo = _repo((req) async {
        paths.add(req.url.path);
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return _json(200, _invoiceJson(7), message: 'Thanh toán thành công.');
      });

      final invoice =
          await repo.pay('12', method: PaymentMethod.qr, promotionCode: 'WELCOME10');
      await repo.pay('12', method: PaymentMethod.cash);
      await repo.pay('12', method: PaymentMethod.card, promotionCode: '');

      expect(paths, everyElement('/api/orders/12/pay'));
      expect(bodies[0], {'payment_method': 'qr', 'promotion_code': 'WELCOME10'});
      expect(bodies[1], {'payment_method': 'cash'});
      expect(bodies[2], {'payment_method': 'card'});
      expect(invoice.displayCode, 'HD00007');
    });

    test('pay với id đơn không phải số (dữ liệu mẫu) báo lỗi dễ hiểu và KHÔNG gọi mạng', () async {
      var calls = 0;
      final repo = _repo((_) async {
        calls++;
        return _json(200, _invoiceJson(1));
      });

      await expectLater(repo.pay('ord1', method: PaymentMethod.cash), throwsA(isA<ApiException>()));
      expect(calls, 0);
    });

    test('pay bị từ chối (khách không đủ điểm) -> ApiException mang lời server', () async {
      final repo = _repo((_) async => _json(422, null, status: 'error', message: 'Khách chỉ có 100 điểm.'));

      await expectLater(
        repo.pay('12', method: PaymentMethod.cash),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.message, 'message', 'Khách chỉ có 100 điểm.')),
      );
    });

    test('fetchAvailablePromotions đọc danh sách voucher còn hiệu lực', () async {
      final repo = _repo((_) async => _json(200, [_promoJson(1, 'WELCOME10', 10, max: 30000)]));
      final promos = await repo.fetchAvailablePromotions();
      expect(promos.single.code, 'WELCOME10');
    });
  });

  group('Số liệu thu ngân tính từ dữ liệu thật', () {
    test('hóa đơn / doanh thu hôm nay, "ca" của thu ngân đang đăng nhập, đơn chờ thanh toán', () async {
      await _signInAs('cashier', id: 3);
      final yesterday = DateTime.now().subtract(const Duration(hours: 40));

      MockData.setInvoices([
        Invoice.fromApiJson(_invoiceJson(1, total: 100000, cashierId: 3)),
        Invoice.fromApiJson(_invoiceJson(2, total: 50000, cashierId: 3)),
        Invoice.fromApiJson(_invoiceJson(3, total: 70000, cashierId: 9, cashierName: 'Thu ngân khác')),
        Invoice.fromApiJson(_invoiceJson(4, total: 999000, cashierId: 3, paidAt: yesterday)),
      ]);

      expect(MockData.todayInvoices.map((i) => i.id), unorderedEquals(['1', '2', '3']));
      expect(MockData.computedTodayRevenue, 220000); // không tính hóa đơn hôm qua
      expect(MockData.myTodayInvoices.map((i) => i.id), unorderedEquals(['1', '2'])); // chỉ của thu ngân này

      MockData.setOrders([
        Order.fromApiJson(_orderJson(1, status: 'serving')), // chờ thanh toán
        Order.fromApiJson(_orderJson(2, status: 'cancelled')), // đã hủy -> không thu
        Order.fromApiJson(_orderJson(3, status: 'completed', payment: 'paid')), // đã trả
        Order.fromApiJson(_orderJson(4, status: 'placed', table: null, customer: 'Khách')), // không bàn
        Order.fromApiJson(_orderJson(5, status: 'preparing', payment: 'pending')), // đang xử lý
        Order.fromApiJson(
            _orderJson(6, status: 'placed', createdAt: DateTime.now().subtract(const Duration(days: 3)))),
      ]);

      expect(MockData.pendingPaymentOrders.map((o) => o.id), ['1', '5', '6']);
      // Đơn hôm nay, trừ đơn đã hủy: 1, 3, 4, 5
      expect(MockData.computedTodayOrderCount, 4);
    });
  });

  group('AppData theo vai trò', () {
    test('chỉ thu ngân / admin tải hóa đơn; voucher thì mọi vai trò đều tải', () async {
      final fake = _FakeInvoices(promos: [Promotion.fromApiJson(_promoJson(1, 'WELCOME10', 10))]);
      InvoiceRepository.instance = fake;

      for (final role in ['order_staff', 'customer']) {
        await _signInAs(role);
        expect(
          AppData.defaultSources(),
          role == 'customer'
              ? {LiveSource.tables, LiveSource.orders, LiveSource.reservations}
              : {LiveSource.tables, LiveSource.orders},
        );
        await AppData.load();
      }
      expect(fake.fetchAllCalls, 0, reason: 'server từ chối (403) nên không được gọi');
      // Voucher (GET /promotions) mọi vai trò đều xem được: khách cần cho Ví voucher.
      expect(fake.promoCalls, 2);
      expect(MockData.promotions.single.code, 'WELCOME10');

      for (final role in ['cashier', 'admin']) {
        await _signInAs(role);
        expect(AppData.defaultSources(), contains(LiveSource.invoices));
      }
      await AppData.load();
      expect(fake.fetchAllCalls, 1);
      expect(fake.promoCalls, 3);
      expect(MockData.availablePromotions.single.code, 'WELCOME10');
    });
  });

  group('Giao diện thanh toán', () {
    void usePhoneSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> pumpPayment(WidgetTester tester, String orderId) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.current,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home: PaymentScreen(orderId: orderId),
      ));
      await tester.pumpAndSettle();
    }

    void seedMemberOrder() {
      MockData.setOrders([Order.fromApiJson(_orderJson(12, customer: 'Lê Minh Khách', points: 320))]);
      MockData.availablePromotions = [
        Promotion.fromApiJson(_promoJson(1, 'WELCOME10', 10, max: 30000)),
        Promotion.fromApiJson(_promoJson(2, 'COMBO15', 15, min: 200000)),
      ];
    }

    testWidgets(
        'đơn của khách thành viên: lọc voucher, dùng điểm, thanh toán gửi đúng dữ liệu, hiện hóa đơn của server',
        (tester) async {
      usePhoneSize(tester);
      seedMemberOrder();
      final calls = <({String orderId, PaymentMethod method, String? code, int points})>[];
      InvoiceRepository.instance = _FakeInvoices(onPay: (orderId, method, code, points) async {
        calls.add((orderId: orderId, method: method, code: code, points: points));
        return Invoice.fromApiJson(_invoiceJson(7));
      });

      await pumpPayment(tester, '12');

      expect(find.text('Dùng điểm thưởng (có 320)'), findsOneWidget);
      expect(find.text('WELCOME10 · -10%'), findsOneWidget);
      expect(find.text('COMBO15 · -15%'), findsNothing); // đơn 74.000đ chưa đạt tối thiểu 200.000đ

      await tester.tap(find.text('WELCOME10 · -10%'));
      await tester.pumpAndSettle();
      expect(find.text('-${AppFormatters.currency(7400)}'), findsOneWidget);

      // Kéo thanh trượt tới hết: dùng tối đa 320 điểm (khách chỉ có 320).
      await tester.drag(find.byType(Slider), const Offset(3000, 0));
      await tester.pumpAndSettle();
      expect(find.text('-${AppFormatters.currency(7720)}'), findsOneWidget);
      expect(find.text(AppFormatters.currency(74000 - 7720)), findsOneWidget);

      await tester.ensureVisible(find.text('QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận thanh toán'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.orderId, '12');
      expect(calls.single.method, PaymentMethod.qr);
      expect(calls.single.code, 'WELCOME10');
      expect(calls.single.points, 320);

      // Màn Hóa đơn hiển thị hóa đơn do SERVER trả về (mã và số tiền của server).
      expect(find.text('Hóa đơn'), findsOneWidget);
      expect(find.text('#HD00007'), findsOneWidget);
      expect(find.text('Đã thanh toán · đơn #OD251008-1012'), findsOneWidget);
      expect(find.text(AppFormatters.currency(66300)), findsWidgets);
    });

    testWidgets('server từ chối: ở lại màn, báo lý do, nút không bị kẹt và không có hóa đơn', (tester) async {
      usePhoneSize(tester);
      seedMemberOrder();
      InvoiceRepository.instance = _FakeInvoices(
        onPay: (_, __, ___, ____) async =>
            throw const ApiException('Khách chỉ có 100 điểm.', statusCode: 422),
      );

      await pumpPayment(tester, '12');
      await tester.tap(find.text('Xác nhận thanh toán'));
      await tester.pumpAndSettle();

      expect(find.text('Khách chỉ có 100 điểm.'), findsOneWidget);
      expect(find.text('Hóa đơn'), findsNothing);
      expect(find.text('Xác nhận thanh toán'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Xác nhận thanh toán')).onPressed,
        isNotNull,
      );
    });

    testWidgets('đơn tại bàn không có khách thành viên: không có phần dùng điểm thưởng', (tester) async {
      usePhoneSize(tester);
      MockData.setOrders([Order.fromApiJson(_orderJson(12))]);
      MockData.availablePromotions = [Promotion.fromApiJson(_promoJson(1, 'WELCOME10', 10))];

      await pumpPayment(tester, '12');

      expect(find.textContaining('Dùng điểm thưởng'), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.text('WELCOME10 · -10%'), findsOneWidget);
    });

    testWidgets('đơn không còn trong danh sách (đã thanh toán / hủy): báo rõ thay vì văng lỗi',
        (tester) async {
      usePhoneSize(tester);
      MockData.setOrders([Order.fromApiJson(_orderJson(1))]);

      await pumpPayment(tester, '999');

      expect(find.text('Không tìm thấy đơn hàng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Lịch sử thanh toán: hiện hóa đơn từ server, mới nhất trước; kéo để làm mới', (tester) async {
      usePhoneSize(tester);
      var serverInvoices = [
        Invoice.fromApiJson(_invoiceJson(2, paidAt: DateTime.now())),
        Invoice.fromApiJson(_invoiceJson(1, paidAt: DateTime.now().subtract(const Duration(hours: 2)))),
      ];
      InvoiceRepository.instance = _FakeInvoices(list: serverInvoices);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.current, home: const HistoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('2 hóa đơn đã thanh toán'), findsOneWidget);
      final first = tester.getTopLeft(find.textContaining('#HD00002')).dy;
      final second = tester.getTopLeft(find.textContaining('#HD00001')).dy;
      expect(first, lessThan(second));

      serverInvoices = [Invoice.fromApiJson(_invoiceJson(3)), ...serverInvoices];
      InvoiceRepository.instance = _FakeInvoices(list: serverInvoices);
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('3 hóa đơn đã thanh toán'), findsOneWidget);
    });
  });
}
