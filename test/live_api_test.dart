import 'dart:io';

import 'package:dineflow/core/api/api_client.dart';
import 'package:dineflow/core/api/api_exception.dart';
import 'package:dineflow/core/session/session_store.dart';
import 'package:dineflow/data/auth_repository.dart';
import 'package:dineflow/data/invoice_repository.dart';
import 'package:dineflow/data/menu_repository.dart';
import 'package:dineflow/data/order_repository.dart';
import 'package:dineflow/data/report_repository.dart';
import 'package:dineflow/data/table_repository.dart';
import 'package:dineflow/models/reservation.dart';
import 'package:dineflow/data/reservation_repository.dart';
import 'package:dineflow/models/invoice.dart';
import 'package:dineflow/models/order.dart';
import 'package:dineflow/models/order_item.dart';
import 'package:dineflow/models/table_model.dart';
import 'package:dineflow/models/user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Test chạy với backend Laravel THẬT (không giả lập).
///
/// Mặc định bị bỏ qua. Để chạy: bật server (`php artisan serve` trong dineflow_backend,
/// database đã `migrate:fresh --seed`), rồi:
///   flutter test test/live_api_test.dart --dart-define=LIVE_API=true
/// Đổi địa chỉ server bằng `--dart-define=API_BASE_URL=http://...:8000/api`.
const _live = bool.fromEnvironment('LIVE_API');

/// Điểm thưởng hiện tại của người đang đăng nhập (đọc từ /me).
Future<int> _points(ApiClient api) async => (await api.get('/me')).map['points'] as int;

const _base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000/api');

void main() {
  setUpAll(() => HttpOverrides.global = null); // flutter_test mặc định chặn mạng thật

  late SessionStore session;
  late ApiClient api;
  late AuthRepository auth;

  setUp(() {
    session = SessionStore();
    api = ApiClient(session: session, baseUrl: _base);
    auth = AuthRepository(api: api, session: session);
  });

  group('Backend thật', skip: _live ? false : 'Đặt --dart-define=LIVE_API=true để chạy', () {
    // Server giới hạn 10 lần đăng nhập/phút (chống dò mật khẩu), nên các test chỉ đọc dữ
    // liệu dùng chung MỘT phiên đăng nhập. Nếu chạy lại liền mà gặp lỗi "quá nhanh" thì đợi 1 phút.
    late String sharedToken;
    late Map<String, dynamic> sharedUser;
    late String customerToken;
    late Map<String, dynamic> customerUser;
    late String cashierToken;
    late Map<String, dynamic> cashierUser;
    late String adminToken;
    late Map<String, dynamic> adminUser;

    // Môi trường test mặc định là Android (địa chỉ ảnh sẽ thành 10.0.2.2, chỉ emulator mới truy cập được);
    // giả lập Windows để địa chỉ ảnh là 127.0.0.1 như máy đang chạy server.
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    setUpAll(() async {
      final res = await ApiClient(session: SessionStore(), baseUrl: _base)
          .post('/login', body: {'login': '0900000002', 'password': '123456'});
      sharedToken = res.map['token'] as String;
      sharedUser = res.map['user'] as Map<String, dynamic>;

      final customer = await ApiClient(session: SessionStore(), baseUrl: _base)
          .post('/login', body: {'login': 'customer@dineflow.com', 'password': '123456'});
      customerToken = customer.map['token'] as String;
      customerUser = customer.map['user'] as Map<String, dynamic>;

      final cashier = await ApiClient(session: SessionStore(), baseUrl: _base)
          .post('/login', body: {'login': '0900000003', 'password': '123456'});
      cashierToken = cashier.map['token'] as String;
      cashierUser = cashier.map['user'] as Map<String, dynamic>;

      final admin = await ApiClient(session: SessionStore(), baseUrl: _base)
          .post('/login', body: {'login': 'admin@dineflow.com', 'password': '123456'});
      adminToken = admin.map['token'] as String;
      adminUser = admin.map['user'] as Map<String, dynamic>;
    });

    Future<void> asStaff() => session.save(sharedToken, sharedUser);
    Future<void> asCustomer() => session.save(customerToken, customerUser);
    Future<void> asCashier() => session.save(cashierToken, cashierUser);

    test('đăng nhập bằng số điện thoại có khoảng trắng, đúng vai trò, lưu token', () async {
      final user = await auth.login('0900 000 002', '123456');

      expect(user.role, UserRole.orderStaff);
      expect(user.email, 'staff@dineflow.com');
      expect(session.token, isNotEmpty);
    });

    test('sai mật khẩu -> 401 kèm thông báo tiếng Việt; tài khoản khóa -> 403', () async {
      await expectLater(
        auth.login('0900000002', 'saimatkhau'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 401)
            .having((e) => e.message, 'message', contains('không đúng'))),
      );
      await expectLater(
        auth.login('locked@dineflow.com', '123456'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
      expect(session.isSignedIn, isFalse);
    });

    test('đăng ký tài khoản mới, ép vai trò Khách hàng, rồi gọi API có token', () async {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final user = await auth.register(
        name: 'Khách Test',
        email: 'live$stamp@example.com',
        phone: '09${stamp.toString().substring(3, 11)}',
        password: 'matkhau1',
      );
      expect(user.role, UserRole.customer);

      final categories = await api.get('/categories');
      expect(categories.list, isNotEmpty);
    });

    test('đăng ký trùng email -> 422 có thông báo', () async {
      await expectLater(
        auth.register(name: 'Trùng', email: 'admin@dineflow.com', phone: '0911111111', password: 'matkhau1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
    });

    test('chưa đăng nhập gọi API -> 401; có token thì đọc được thực đơn và bàn', () async {
      await expectLater(
          api.get('/foods'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));

      await asStaff();
      final foods = await api.get('/foods', query: {'category_id': '1'});
      expect(foods.list.map((f) => f['name']), contains('Cà phê sữa đá'));
      expect(foods.list.first['options'], isA<List>());

      final tables = await api.get('/tables', query: {'area': 'Tầng 1'});
      expect(tables.list, hasLength(6));
      expect(tables.meta['areas'], contains('Tầng 2'));
    });

    test('thực đơn thật: 6 danh mục, 14 món có size/topping, mọi ảnh tải về được', () async {
      await asStaff();

      final menu = await MenuRepository(api: api).fetch();

      expect(menu.categories, hasLength(6));
      expect(menu.foods, hasLength(14));

      final tea = menu.foods.firstWhere((f) => f.name == 'Trà sữa trân châu');
      expect(tea.sizes.map((o) => o.name), ['Size S', 'Size M', 'Size L']);
      expect(tea.toppings.map((o) => o.name), contains('Trân châu'));
      expect(tea.isBestSeller, isTrue);
      expect(menu.foods.firstWhere((f) => f.name == 'Tiramisu').isAvailable, isFalse);

      // Mọi món phải có link ảnh và link đó tải được ảnh thật.
      expect(menu.foods.where((f) => f.image == null), isEmpty);
      for (final food in menu.foods) {
        final res = await http.get(Uri.parse(food.image!));
        expect(res.statusCode, 200, reason: 'ảnh của ${food.name}: ${food.image}');
        expect(res.headers['content-type'], contains('image'));
        expect(res.bodyBytes.length, greaterThan(10000));
      }
    });

    test('bàn thật: 12 bàn, đúng thứ tự khu vực, bàn đang phục vụ có đơn và giờ bắt đầu', () async {
      await asStaff();

      final tables = await TableRepository(api: api).fetch();

      expect(tables, hasLength(12));
      expect(tables.first.number, 'Bàn 1');
      // Thứ tự khu vực theo lúc tạo bàn, không xếp theo chữ cái.
      expect(tables.map((t) => t.area).toSet().toList(), ['Tầng 1', 'Tầng 2', 'Ngoài trời']);

      final serving = tables.where((t) => t.status == TableStatus.serving).toList();
      expect(serving.map((t) => t.number), containsAll(['Bàn 2', 'Bàn 5', 'Bàn 8']));
      for (final t in serving) {
        expect(t.currentOrderId, isNotNull, reason: '${t.number} đang phục vụ phải có đơn');
        expect(t.servingSince, isNotNull);
        expect(t.servingSince!.isBefore(DateTime.now()), isTrue);
      }
      expect(tables.where((t) => t.status == TableStatus.reserved), isNotEmpty);
    });

    test('đơn hàng thật: tạo, gọi thêm món vào cùng đơn, đổi trạng thái, hủy thì trả bàn', () async {
      await asStaff();
      final orders = OrderRepository(api: api);
      final tablesRepo = TableRepository(api: api);

      final menu = await MenuRepository(api: api).fetch();
      final coffee = menu.foods.firstWhere((f) => f.name == 'Cà phê sữa đá');
      final friedChicken = menu.foods.firstWhere((f) => f.name == 'Gà cánh chiên nước mắm');
      final sizeM = coffee.sizes.firstWhere((o) => o.name == 'Size M');
      final table = (await tablesRepo.fetch()).firstWhere((t) => t.number == 'Bàn 1');
      expect(table.status, TableStatus.empty,
          reason: 'cần seed lại DB (migrate:fresh --seed) trước khi chạy');

      // 1) Tạo đơn: giá do server tính (29.000 + 8.000) x 2
      final created = await orders.create(
        tableId: table.id,
        note: 'Test live',
        items: [
          OrderItem(
            id: 'x',
            foodId: coffee.id,
            foodName: coffee.name,
            price: 1, // cố tình sai: server phải bỏ qua và dùng giá thật
            quantity: 2,
            selectedOptions: [sizeM],
            note: 'Ít đá',
          ),
        ],
      );
      final order = created.order;
      expect(created.message, 'Tạo đơn hàng thành công.');
      expect(order.code, startsWith('OD'));
      expect(order.tableNumber, 'Bàn 1');
      expect(order.status, OrderStatus.placed);
      expect(order.subtotal, 74000);
      expect(order.items.single.selectedOptions.single.name, 'Size M');
      expect(order.items.single.note, 'Ít đá');

      // 2) Bàn chuyển sang đang phục vụ và trỏ tới đơn này
      final busy = (await tablesRepo.fetch()).firstWhere((t) => t.id == table.id);
      expect(busy.status, TableStatus.serving);
      expect(busy.currentOrderId, order.id);

      // 3) Gọi thêm món cho cùng bàn -> vào đúng đơn cũ, không tạo đơn mới
      final more = await orders.create(tableId: table.id, items: [
        OrderItem(id: 'y', foodId: friedChicken.id, foodName: friedChicken.name, price: 0),
      ]);
      expect(more.order.id, order.id);
      expect(more.message, contains('thêm món'));
      expect(more.order.items, hasLength(2));
      expect(more.order.subtotal, 74000 + 48000);

      // 4) Có trong danh sách đơn
      final all = await orders.fetchAll();
      expect(all.where((o) => o.id == order.id), hasLength(1));

      // 5) Đổi trạng thái: tiến được, lùi thì bị từ chối
      expect((await orders.updateStatus(order.id, OrderStatus.preparing)).status, OrderStatus.preparing);
      await expectLater(
        orders.updateStatus(order.id, OrderStatus.placed),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );

      // 6) Hủy đơn (13/11): NV Order không hủy qua đổi trạng thái; Thu ngân hủy kèm lý do -> bàn về trống
      await expectLater(
        orders.updateStatus(order.id, OrderStatus.cancelled),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
      await asCashier();
      await api.patch('/orders/${order.id}/cancel', body: {'reason': 'wrong_entry'});
      await asStaff();
      final freed = (await tablesRepo.fetch()).firstWhere((t) => t.id == table.id);
      expect(freed.status, TableStatus.empty);
      expect(freed.currentOrderId, isNull);
    });

    test('món hết hàng bị từ chối với thông báo rõ ràng', () async {
      await asStaff();
      final menu = await MenuRepository(api: api).fetch();
      final tiramisu = menu.foods.firstWhere((f) => f.name == 'Tiramisu');

      await expectLater(
        OrderRepository(api: api).create(
          tableId: '1',
          items: [OrderItem(id: 'z', foodId: tiramisu.id, foodName: tiramisu.name, price: 0)],
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.message, 'message', contains('không phục vụ'))),
      );
    });

    test('khách hàng chỉ thấy đơn của chính mình', () async {
      await asCustomer();

      final mine = await OrderRepository(api: api).fetchAll();

      expect(mine, isNotEmpty);
      expect(mine.every((o) => o.customerName == 'Lê Minh Khách'), isTrue);
    });

    test('thanh toán thật: voucher, hóa đơn, bàn về trống; trả hai lần và sai vai trò bị từ chối', () async {
      final orders = OrderRepository(api: api);
      final invoices = InvoiceRepository(api: api);

      // Nhân viên tạo đơn 2 Cà phê sữa đá Size M tại Bàn 1 (74.000đ)
      await asStaff();
      final menu = await MenuRepository(api: api).fetch();
      final coffee = menu.foods.firstWhere((f) => f.name == 'Cà phê sữa đá');
      final order = (await orders.create(tableId: '1', items: [
        OrderItem(
          id: 'x',
          foodId: coffee.id,
          foodName: coffee.name,
          price: 0,
          quantity: 2,
          selectedOptions: [coffee.sizes.firstWhere((o) => o.name == 'Size M')],
        ),
      ]))
          .order;

      // Nhân viên không được thu tiền, cũng không xem được hóa đơn
      await expectLater(
        invoices.pay(order.id, method: PaymentMethod.cash),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
      await expectLater(
        invoices.fetchAll(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );

      await asCashier();

      // Voucher còn hiệu lực: có WELCOME10 và COMBO15, không có voucher đã hết hạn / chưa bắt đầu
      final codes = (await invoices.fetchAvailablePromotions()).map((p) => p.code).toList();
      expect(codes, containsAll(['WELCOME10', 'COMBO15']));
      expect(codes, isNot(contains('TET2025')));
      expect(codes, isNot(contains('SUMMER20')));

      // Đơn đã cần thanh toán, thu ngân thấy được
      final pending = (await orders.fetchAll()).firstWhere((o) => o.id == order.id);
      expect(pending.paymentStatus, PaymentStatus.unpaid);

      // Thanh toán QR + WELCOME10: 74.000 - 10% (7.400) = 66.600
      final invoice = await invoices.pay(order.id, method: PaymentMethod.qr, promotionCode: 'WELCOME10');
      expect(invoice.displayCode, startsWith('HD'));
      expect(invoice.displayOrderCode, order.code);
      expect(invoice.tableNumber, 'Bàn 1');
      expect(invoice.subtotal, 74000);
      expect(invoice.discount, 7400);
      expect(invoice.total, 66600);
      expect(invoice.paymentMethod, PaymentMethod.qr);
      expect(invoice.cashierId, cashierUser['id'].toString());

      // Bàn về trống, đơn đã thanh toán
      final table = (await TableRepository(api: api).fetch()).firstWhere((t) => t.number == 'Bàn 1');
      expect(table.status, TableStatus.empty);
      final paid = (await orders.fetchAll()).firstWhere((o) => o.id == order.id);
      expect(paid.paymentStatus, PaymentStatus.paid);
      expect(paid.status, OrderStatus.completed);

      // Hóa đơn mới nằm đầu danh sách
      final list = await invoices.fetchAll();
      expect(list.first.id, invoice.id);
      expect(list.length, greaterThanOrEqualTo(8));

      // Trả hai lần bị từ chối
      await expectLater(
        invoices.pay(order.id, method: PaymentMethod.cash),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
    });

    test('dùng điểm thưởng thật: trừ điểm của khách; quá số điểm thì bị từ chối và không đổi gì', () async {
      final orders = OrderRepository(api: api);
      final invoices = InvoiceRepository(api: api);

      // Khách tự đặt (không bàn) 2 ly = 58.000đ
      await asCustomer();
      final menu = await MenuRepository(api: api).fetch();
      final coffee = menu.foods.firstWhere((f) => f.name == 'Cà phê sữa đá');
      expect(await _points(api), 320, reason: 'cần seed lại DB (migrate:fresh --seed) trước khi chạy');
      final order = (await orders.create(items: [
        OrderItem(id: 'c', foodId: coffee.id, foodName: coffee.name, price: 0, quantity: 2),
      ]))
          .order;

      await asCashier();
      final seen = (await orders.fetchAll()).firstWhere((o) => o.id == order.id);
      expect(seen.customerName, 'Lê Minh Khách');
      expect(seen.customerPoints, 320); // thu ngân biết khách có bao nhiêu điểm

      // Dùng quá số điểm đang có -> 422, đơn vẫn chưa thanh toán
      await expectLater(
        invoices.pay(order.id, method: PaymentMethod.cash),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
      );
      expect(
          (await orders.fetchAll()).firstWhere((o) => o.id == order.id).paymentStatus, PaymentStatus.unpaid);

      // Dùng 300 điểm: 58.000 - 300
      final invoice = await invoices.pay(order.id, method: PaymentMethod.cash);
      expect(invoice.discount, 300);
      expect(invoice.total, 57700);

      await asCustomer();
      expect(await _points(api), 20);
    });

    test('đặt bàn thật: giữ bàn -> trùng giờ bị từ chối -> xác nhận kèm món -> hủy thì nhả bàn', () async {
      await asCustomer();
      final reservations = ReservationRepository(api: api);
      final tables = (await TableRepository(api: api).fetch())
          .where((t) => t.number == 'Bàn 11' || t.number == 'Bàn 12')
          .toList();
      final menu = await MenuRepository(api: api).fetch();
      final rice = menu.foods.firstWhere((f) => f.name == 'Cơm sườn nướng');
      final day = DateTime.now().add(const Duration(days: 5));
      final when = DateTime(day.year, day.month, day.day, 19);

      // Bước 1: giữ hai bàn ghép (4 + 6 chỗ) cho 8 khách
      final held = await reservations.hold(tables: tables, dateTime: when, guestCount: 8, note: 'Test live');
      expect(held.isHeld, isTrue);
      expect(held.tableNumbers, ['Bàn 11', 'Bàn 12']);
      expect(held.capacity, 10);
      expect(held.dateTime, when, reason: 'giờ không được lệch múi giờ');
      final left = held.holdExpiresAt!.difference(DateTime.now());
      expect(left, greaterThan(const Duration(minutes: 9)));
      expect(left, lessThanOrEqualTo(const Duration(minutes: 10, seconds: 5)));

      // Đang giữ thì đặt trùng bàn / khung giờ bị từ chối
      await expectLater(
        reservations
            .hold(tables: [tables.first], dateTime: when.add(const Duration(hours: 1)), guestCount: 2),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.message, 'message', contains('đã có người đặt'))),
      );
      expect((await reservations.fetchMine()).firstWhere((r) => r.id == held.id).isHeld, isTrue);

      // Bước cuối: xác nhận kèm 2 Cơm sườn nướng (giá do server tính = 110.000)
      final confirmed = await reservations.confirm(
        held.id,
        items: [OrderItem(id: 'x', foodId: rice.id, foodName: rice.name, price: 0, quantity: 2)],
        payment: PaymentMethod.qr,
      );
      expect(confirmed.isHeld, isFalse);
      expect(confirmed.preOrderTotal, 110000);
      expect(confirmed.preOrderPayment, PaymentMethod.qr);

      // Hủy thì nhả bàn: đặt lại đúng giờ đó được
      expect((await reservations.cancel(held.id)).status, ReservationStatus.cancelled);
      final again = await reservations.hold(tables: tables, dateTime: when, guestCount: 8);
      expect(again.isHeld, isTrue);
      await reservations.cancel(again.id); // dọn dẹp
    });

    test('báo cáo thật: admin xem được số liệu 7 ngày / 6 tuần / 6 tháng; vai trò khác bị từ chối', () async {
      await session.save(adminToken, adminUser);
      final report = await ReportRepository(api: api).fetchOverview();

      expect(report.revenueByDay, hasLength(7));
      expect(report.revenueByWeek, hasLength(6));
      expect(report.revenueByMonth, hasLength(6));
      expect(report.todayRevenue, greaterThan(0)); // dữ liệu mẫu có hóa đơn hôm nay
      final sevenDays = report.revenueByDay.fold<double>(0, (a, p) => a + p.amount);
      final sixMonths = report.revenueByMonth.fold<double>(0, (a, p) => a + p.amount);
      expect(sevenDays, greaterThanOrEqualTo(report.todayRevenue));
      expect(sixMonths, greaterThanOrEqualTo(sevenDays));
      expect(report.topFoods, isNotEmpty);
      final sold = report.topFoods.map((f) => f.soldQuantity).toList();
      expect(sold, [...sold]..sort((a, b) => b.compareTo(a)));

      await asStaff();
      await expectLater(ReportRepository(api: api).fetchOverview(),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    });

    test('đăng xuất thu hồi token trên server', () async {
      await auth.login('0900000003', '123456');
      final oldToken = session.token!;

      await auth.logout();
      expect(session.isSignedIn, isFalse);

      // Dùng lại token cũ -> server phải từ chối
      final stale = SessionStore();
      await stale.save(oldToken, {'id': 3, 'name': 'x', 'email': 'x', 'phone': '', 'role': 'cashier'});
      final staleApi = ApiClient(session: stale, baseUrl: _base);
      await expectLater(
          staleApi.get('/me'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    });

    test('không có server (cổng sai) -> lỗi mạng thân thiện, không phải crash', () async {
      final dead = ApiClient(session: SessionStore(), baseUrl: 'http://127.0.0.1:9/api');

      await expectLater(
        dead.get('/foods'),
        throwsA(isA<ApiException>().having((e) => e.isNetworkError, 'isNetworkError', true)),
      );
    });
  });
}
