import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dineflow/core/api/api_client.dart';
import 'package:dineflow/core/api/api_exception.dart';
import 'package:dineflow/core/session/session_store.dart';
import 'package:dineflow/data/reservation_repository.dart';
import 'package:dineflow/models/invoice.dart';
import 'package:dineflow/models/order_item.dart';
import 'package:dineflow/models/table_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dineflow/app/app.dart';
import 'package:dineflow/data/cart_store.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/models/reservation.dart';
import 'package:dineflow/screens/customer/booking_checkout.dart';

/// Dùng kích thước màn hình điện thoại thực tế (thay vì mặc định 800x600 của
/// test) để các phần tử cuối trang không bị coi là "off-screen" khi tap.
void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Đăng nhập bằng số điện thoại (mặc định vào vai trò Khách hàng).
Future<void> _loginAsCustomer(WidgetTester tester) async {
  await tester.pumpWidget(const DineFlowApp());
  await tester.pumpAndSettle();

  final textFields = find.byType(TextFormField);
  await tester.enterText(textFields.at(0), '0901234567');
  await tester.enterText(textFields.at(1), '1234');
  await _tapVisible(tester, find.text('Đăng nhập'));
}

/// Mở tab Đặt bàn từ nút "Đặt bàn ngay" ở Trang chủ, chọn ngày mai và 19:00.
/// Chọn ngày mai để mọi khung giờ đều khả dụng, bất kể test chạy lúc mấy giờ.
Future<void> _openBookingAndPickTomorrowEvening(WidgetTester tester) async {
  await _tapVisible(tester, find.text('Đặt bàn ngay'));
  expect(find.text('Chọn ngày, giờ và số khách'), findsOneWidget);

  await _tapVisible(tester, find.byKey(const ValueKey('booking-date-1')));
  await _tapVisible(tester, find.byKey(const ValueKey('booking-time-19:00')));
}

/// Bước 1: chọn Bàn 1 rồi xác nhận giữ bàn -> sang bước 2 "Đặt món trước".
Future<Reservation> _holdTable1(WidgetTester tester) async {
  await _tapVisible(tester, find.text('Bàn 1'));
  await _tapVisible(tester, _confirmButton);
  expect(find.text('Đặt món trước'), findsOneWidget);
  return MockData.reservations.first;
}

/// Thẻ đặt bàn có mã [code] ở tab Lịch đặt; cuộn danh sách tới thẻ đó trước
/// (thẻ có món đặt trước khá cao nên thẻ sau có thể nằm dưới màn hình).
Future<Finder> _bookingCard(WidgetTester tester, String code) async {
  final codeText = find.text('Mã $code');
  await tester.scrollUntilVisible(
    codeText,
    200,
    scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first,
  );
  await tester.pumpAndSettle();
  return find.ancestor(
    of: codeText,
    matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BookingCard'),
  );
}

Finder get _confirmButton => find.byKey(const ValueKey('booking-confirm'));
Finder get _preOrderNext => find.byKey(const ValueKey('pre-order-next'));
Finder get _payButton => find.byKey(const ValueKey('booking-pay'));

void main() {
  testWidgets(
    'Đặt bàn qua app, bỏ qua đặt món: đặt bàn -> thanh toán -> thành công -> lịch đặt -> huỷ',
    (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);

      // ----- Trang chủ: thẻ lịch đặt bàn sắp tới (dữ liệu mẫu r1) kèm nút Đặt bàn ngay -----
      expect(find.text('LỊCH ĐẶT BÀN SẮP TỚI'), findsOneWidget);
      expect(find.text('Đặt bàn ngay'), findsOneWidget);

      // ----- Bước 1: Đặt bàn -----
      await _openBookingAndPickTomorrowEvening(tester);
      expect(find.textContaining('lúc 19:00'), findsOneWidget);
      // Chọn bàn trước: danh sách cuộn xuống nên ô Ghi chú ở cuối trang mới được dựng.
      await _tapVisible(tester, find.text('Bàn 1'));
      await tester.enterText(find.byType(TextField).last, 'Bàn gần cửa sổ, cảm ơn nhà hàng.');
      await _tapVisible(tester, _confirmButton);
      expect(find.text('Đặt món trước'), findsOneWidget);
      final created = MockData.reservations.first;
      expect(BookingCheckout.instance.isActive, isTrue);

      // ----- Bước 2: Đặt món trước - bỏ qua -----
      expect(find.text('Bỏ qua, thanh toán'), findsOneWidget);
      await _tapVisible(tester, _preOrderNext);

      // ----- Bước 3: Thanh toán - không có món nên chỉ cần xác nhận giữ bàn -----
      // "Thanh toán" xuất hiện 2 lần (tiêu đề + nhãn bước 3) nên kiểm tra phụ đề riêng của màn.
      expect(find.text('Hoàn tất để chốt lượt đặt bàn'), findsOneWidget);
      expect(find.text('Xác nhận giữ bàn'), findsOneWidget);
      await _tapVisible(tester, _payButton);

      // ----- Thành công -----
      expect(find.text('Đặt bàn thành công!'), findsOneWidget);
      expect(find.text(created.code), findsOneWidget);
      expect(find.text('Không cần trả trước'), findsOneWidget);
      expect(BookingCheckout.instance.isActive, isFalse);

      await _tapVisible(tester, find.text('Xem lịch đặt'));

      // ----- Tab Lịch đặt: có 2 lượt "Sắp tới" (1 dữ liệu mẫu + 1 vừa tạo) -----
      expect(find.text('Lịch đặt bàn'), findsOneWidget);
      expect(find.text('Sắp tới (2)'), findsOneWidget);
      final card = await _bookingCard(tester, created.code);
      expect(find.descendant(of: card, matching: find.text('Không đặt món trước')), findsOneWidget);

      await _tapVisible(
          tester, find.descendant(of: card, matching: find.widgetWithText(OutlinedButton, 'Huỷ đặt bàn')));
      expect(find.text('Huỷ đặt bàn?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Huỷ đặt bàn'));
      await tester.pumpAndSettle();

      // Tab tự cập nhật sau khi huỷ: lượt vừa huỷ chuyển sang Lịch sử.
      expect(find.text('Đã huỷ đặt bàn'), findsOneWidget);
      expect(find.text('Sắp tới (1)'), findsOneWidget);
      expect(MockData.reservations.firstWhere((r) => r.id == created.id).status, ReservationStatus.cancelled);
    },
  );

  testWidgets(
    'Ghép bàn + đặt món trước: 5 khách ghép 2 bàn, chọn món, thanh toán',
    (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);
      await _openBookingAndPickTomorrowEvening(tester);

      // Nâng số khách từ 2 lên 5.
      final stepper = find.byKey(const ValueKey('booking-guest-stepper'));
      final plus = find.descendant(of: stepper, matching: find.byIcon(Icons.add_rounded));
      for (var i = 0; i < 3; i++) {
        await _tapVisible(tester, plus);
      }
      expect(find.descendant(of: stepper, matching: find.text('5')), findsOneWidget);

      // Bàn trống lớn nhất chỉ 4 ghế: chọn một bàn là chưa đủ chỗ -> bị chặn.
      await _tapVisible(tester, find.text('Bàn 1'));
      expect(find.textContaining('còn thiếu 1 chỗ'), findsOneWidget);
      await _tapVisible(tester, _confirmButton);
      expect(find.text('Đặt món trước'), findsNothing);

      // Ghép thêm Bàn 4 -> 8 chỗ, đủ cho 5 khách.
      await _tapVisible(tester, find.text('Bàn 4'));
      expect(find.textContaining('Ghép 2 bàn'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4)); // chờ snackbar cảnh báo tắt
      await tester.pumpAndSettle();
      await _tapVisible(tester, _confirmButton);

      // ----- Bước 2: chọn 1 món -----
      expect(find.text('Đặt món trước'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const ValueKey('add')).first);
      expect(find.text('Tiếp tục thanh toán'), findsOneWidget);
      await _tapVisible(tester, _preOrderNext);

      // ----- Bước 3: có món nên phải chọn phương thức và thanh toán -----
      expect(find.text('Phương thức thanh toán'), findsOneWidget);
      expect(find.textContaining('Thanh toán ', findRichText: true), findsWidgets);
      await _tapVisible(tester, _payButton);

      expect(find.text('Đặt bàn thành công!'), findsOneWidget);
      expect(find.textContaining('Bàn 1 + Bàn 4'), findsOneWidget);
      expect(find.text('1 món'), findsOneWidget);

      final created = MockData.reservations.first;
      expect(created.isMerged, isTrue);
      expect(created.capacity, 8);
      expect(created.guestCount, 5);
      expect(created.status, ReservationStatus.upcoming);
      // Món đặt trước được lưu vào lượt đặt bàn, danh sách món đã chọn được làm trống.
      expect(created.preOrderQuantity, 1);
      expect(AppCart.customer.isEmpty, isTrue);
    },
  );

  testWidgets(
    'Quá thời gian giữ bàn mà chưa xong 3 bước thì lượt đặt bàn tự huỷ',
    (tester) async {
      // Rút ngắn thời gian giữ bàn để không phải chờ 10 phút trong test.
      BookingCheckout.holdDuration = Duration.zero;
      addTearDown(() => BookingCheckout.holdDuration = const Duration(minutes: 10));

      _usePhoneSize(tester);
      await _loginAsCustomer(tester);
      await _openBookingAndPickTomorrowEvening(tester);
      final held = await _holdTable1(tester);
      expect(held.status, ReservationStatus.upcoming);

      // Đồng hồ kiểm tra mỗi giây.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Hết thời gian giữ bàn'), findsOneWidget);
      final afterExpiry = MockData.reservations.firstWhere((r) => r.id == held.id);
      expect(afterExpiry.status, ReservationStatus.cancelled);

      await tester.tap(find.text('Đặt lại'));
      await tester.pumpAndSettle();
      expect(find.text('Đặt món trước'), findsNothing);
      expect(_confirmButton, findsOneWidget);
    },
  );

  testWidgets(
    'Thoát khỏi bước Đặt món trước thì hỏi lại và huỷ lượt giữ bàn',
    (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);
      await _openBookingAndPickTomorrowEvening(tester);
      final held = await _holdTable1(tester);

      // Giả lập nút Back của hệ điều hành.
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();

      expect(find.text('Huỷ đặt bàn?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Huỷ đặt bàn'));
      await tester.pumpAndSettle();

      final afterLeave = MockData.reservations.firstWhere((r) => r.id == held.id);
      expect(afterLeave.status, ReservationStatus.cancelled);
      expect(BookingCheckout.instance.isActive, isFalse);
      expect(_confirmButton, findsOneWidget);
    },
  );

  testWidgets(
    'Chọn món ở Thực đơn rồi đặt bàn: món có sẵn ở bước Đặt món trước và hiện ở Lịch đặt',
    (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);

      // ----- Thực đơn: nút "+" chỉ chọn món, chưa gửi đi đâu -----
      await _tapVisible(tester, find.text('Thực đơn'));
      await _tapVisible(tester, find.byIcon(Icons.add_rounded).first);
      expect(find.text('1 món đã chọn'), findsOneWidget);

      // ----- Bảng "Món đã chọn": xem lại món, nút cuối mở tab Đặt bàn -----
      await _tapVisible(tester, find.byKey(const ValueKey('picked-foods-open')));
      expect(find.text('Món đã chọn'), findsOneWidget);
      expect(find.textContaining('Món được gửi cho nhà hàng khi bạn đặt bàn'), findsOneWidget);
      await _tapVisible(tester, find.text('Đặt bàn để gọi món'));

      // Sang tab Đặt bàn; thanh món đã chọn chỉ hiện ở Trang chủ / Thực đơn nên ẩn đi.
      expect(find.text('Chọn ngày, giờ và số khách'), findsOneWidget);
      expect(find.textContaining('1 món bạn đã chọn'), findsOneWidget);
      expect(find.text('1 món đã chọn'), findsNothing);

      await _tapVisible(tester, find.byKey(const ValueKey('booking-date-1')));
      await _tapVisible(tester, find.byKey(const ValueKey('booking-time-19:00')));
      await _holdTable1(tester);

      // ----- Bước 2: món đã chọn có sẵn nên đi tiếp là thanh toán -----
      expect(find.text('Tiếp tục thanh toán'), findsOneWidget);
      await _tapVisible(tester, _preOrderNext);
      await _tapVisible(tester, _payButton);
      expect(find.text('Đặt bàn thành công!'), findsOneWidget);
      expect(find.text('1 món'), findsOneWidget);

      final created = MockData.reservations.first;
      expect(created.preOrderQuantity, 1);
      expect(AppCart.customer.isEmpty, isTrue);

      // ----- Tab Lịch đặt: thẻ đặt bàn vừa tạo kèm món đặt trước -----
      await _tapVisible(tester, find.text('Xem lịch đặt'));
      final card = await _bookingCard(tester, created.code);
      expect(find.descendant(of: card, matching: find.text('Món đặt trước · 1 món')), findsOneWidget);
    },
  );

  group('Đặt bàn qua server', () {
    late ReservationRepository originalRepo;
    late _ReservationSim sim;

    setUp(() {
      originalRepo = ReservationRepository.instance;
      sim = _ReservationSim();
      ReservationRepository.instance = sim;
    });

    tearDown(() => ReservationRepository.instance = originalRepo);

    testWidgets('gửi đúng bàn, giờ, ghi chú khi giữ bàn; đúng món + phương thức khi xác nhận',
        (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);

      await _openBookingAndPickTomorrowEvening(tester);
      await _tapVisible(tester, find.text('Bàn 1'));
      await tester.enterText(find.byType(TextField).last, '  Gần cửa sổ  ');
      await _tapVisible(tester, _confirmButton);

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final hold = sim.holds.single;
      expect(hold.tables, ['Bàn 1']);
      expect((hold.dateTime.year, hold.dateTime.month, hold.dateTime.day),
          (tomorrow.year, tomorrow.month, tomorrow.day));
      expect((hold.dateTime.hour, hold.dateTime.minute), (19, 0));
      expect(hold.note, 'Gần cửa sổ');
      expect(BookingCheckout.instance.reservation!.isHeld, isTrue);

      // Bước 2: chọn một món đặt trước, bước 3: thanh toán
      await _tapVisible(tester, find.byIcon(Icons.add_rounded).first);
      await _tapVisible(tester, _preOrderNext);
      await _tapVisible(tester, _payButton);

      final confirm = sim.confirms.single;
      expect(confirm.id, MockData.reservations.first.id);
      expect(confirm.items.single.quantity, 1);
      expect(confirm.payment, PaymentMethod.qr);
      expect(find.text('Đặt bàn thành công!'), findsOneWidget);
      expect(MockData.reservations.first.isHeld, isFalse); // đã xác nhận: hết hạn giữ bàn
    });

    testWidgets('server từ chối giữ bàn (đã có người đặt): ở lại màn, báo lý do, không bắt đầu phiên',
        (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);
      final before = MockData.reservations.length;
      sim.holdError = const ApiException('Bàn 1 đã có người đặt trong khung giờ này.', statusCode: 422);

      await _openBookingAndPickTomorrowEvening(tester);
      await _tapVisible(tester, find.text('Bàn 1'));
      await _tapVisible(tester, _confirmButton);

      expect(find.text('Bàn 1 đã có người đặt trong khung giờ này.'), findsOneWidget);
      expect(find.text('Đặt món trước'), findsNothing);
      expect(_confirmButton, findsOneWidget); // vẫn ở màn chọn bàn, bấm lại được
      expect(BookingCheckout.instance.isActive, isFalse);
      expect(MockData.reservations.length, before);
    });

    testWidgets(
        'xác nhận bị từ chối vì server đã hủy lượt giữ bàn (hết hạn): nhả bàn, về trang chủ, báo lý do',
        (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);
      sim.confirmError = const ApiException(
        'Lượt giữ bàn đã hết hạn hoặc đã bị hủy. Vui lòng đặt lại.',
        statusCode: 422,
      );
      sim.expireOnConfirmError = true; // server đã hủy lượt đặt này

      await _openBookingAndPickTomorrowEvening(tester);
      final held = await _holdTable1(tester);
      await _tapVisible(tester, _preOrderNext);
      await _tapVisible(tester, _payButton);

      expect(find.text('Đặt bàn thành công!'), findsNothing);
      expect(find.text('Lượt giữ bàn đã hết hạn hoặc đã bị hủy. Vui lòng đặt lại.'), findsOneWidget);
      expect(BookingCheckout.instance.isActive, isFalse);
      expect(MockData.reservations.firstWhere((r) => r.id == held.id).status, ReservationStatus.cancelled);
      expect(find.text('Xác nhận giữ bàn'), findsNothing); // đã rời màn thanh toán
    });

    testWidgets('xác nhận bị từ chối nhưng lượt đặt còn nguyên (vd. món hết hàng): ở lại màn thanh toán',
        (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);
      sim.confirmError = const ApiException('Món "Tiramisu" hiện không phục vụ.', statusCode: 422);

      await _openBookingAndPickTomorrowEvening(tester);
      await _holdTable1(tester);
      await _tapVisible(tester, _preOrderNext);
      await _tapVisible(tester, _payButton);

      expect(find.text('Món "Tiramisu" hiện không phục vụ.'), findsOneWidget);
      expect(find.text('Xác nhận giữ bàn'), findsOneWidget); // vẫn ở màn thanh toán
      expect(BookingCheckout.instance.isActive, isTrue); // còn giữ bàn để khách sửa món rồi thử lại
      expect(
          tester
              .widget<ElevatedButton>(find.descendant(of: _payButton, matching: find.byType(ElevatedButton)))
              .onPressed,
          isNotNull);

      // Thông báo lỗi tự ẩn sau 3 giây (nó nổi đè lên nút), rồi thử lại thành công khi server không còn từ chối
      sim.confirmError = null;
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await _tapVisible(tester, _payButton);
      expect(find.text('Đặt bàn thành công!'), findsOneWidget);
    });

    testWidgets('thoát giữa chừng thì báo server nhả bàn; server lỗi mạng cũng không làm kẹt app',
        (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);
      sim.cancelError = const ApiException('Không kết nối được máy chủ.');

      await _openBookingAndPickTomorrowEvening(tester);
      final held = await _holdTable1(tester);

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.maybePop();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Huỷ đặt bàn'));
      await tester.pumpAndSettle();

      expect(sim.cancels, [held.id]);
      expect(BookingCheckout.instance.isActive, isFalse);
      expect(MockData.reservations.firstWhere((r) => r.id == held.id).status, ReservationStatus.cancelled);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Lịch đặt: hủy gọi server; server từ chối thì giữ nguyên lượt đặt và báo lỗi',
        (tester) async {
      _usePhoneSize(tester);
      await _loginAsCustomer(tester);
      await _tapVisible(tester, find.text('Lịch đặt'));

      Future<void> cancelSample() async {
        final card = await _bookingCard(tester, 'DF7421');
        await _tapVisible(
            tester, find.descendant(of: card, matching: find.widgetWithText(OutlinedButton, 'Huỷ đặt bàn')));
        await tester.tap(find.widgetWithText(TextButton, 'Huỷ đặt bàn'));
        await tester.pumpAndSettle();
      }

      sim.cancelError =
          const ApiException('Chỉ hủy được lượt đặt đang ở trạng thái "Sắp tới".', statusCode: 422);
      await cancelSample();
      expect(find.text('Chỉ hủy được lượt đặt đang ở trạng thái "Sắp tới".'), findsOneWidget);
      expect(MockData.reservations.firstWhere((r) => r.id == 'r1').status, ReservationStatus.upcoming);

      // Thông báo lỗi nổi đè lên nút nên chờ nó tự ẩn rồi mới bấm hủy lại
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      sim.cancelError = null;
      await cancelSample();
      expect(sim.cancels, ['r1', 'r1']);
      expect(find.text('Đã huỷ đặt bàn'), findsOneWidget);
      expect(MockData.reservations.firstWhere((r) => r.id == 'r1').status, ReservationStatus.cancelled);
    });
  });
}

/// Server đặt bàn giả cho test giao diện: ghi lại các lời gọi và cho phép giả lập lỗi.
class _ReservationSim extends ReservationRepository {
  _ReservationSim()
      : super(
          api: ApiClient(
            client: MockClient((_) async => http.Response('{}', 200)),
            session: SessionStore(),
            baseUrl: 'http://t/api',
          ),
        );

  final holds = <({List<String> tables, DateTime dateTime, int guests, String? note})>[];
  final confirms = <({String id, List<OrderItem> items, PaymentMethod? payment})>[];
  final cancels = <String>[];
  final _expired = <String>{};

  ApiException? holdError;
  ApiException? confirmError;
  ApiException? cancelError;

  /// Khi `confirm` bị từ chối, coi như server đã hủy lượt đặt đó (hết hạn giữ bàn).
  bool expireOnConfirmError = false;

  @override
  Future<List<Reservation>> fetchMine() async => [
        for (final r in MockData.reservations)
          _expired.contains(r.id) ? r.copyWith(status: ReservationStatus.cancelled, clearHold: true) : r,
      ];

  @override
  Future<Reservation> hold({
    required List<TableModel> tables,
    required DateTime dateTime,
    required int guestCount,
    String? note,
  }) async {
    holds.add(
        (tables: tables.map((t) => t.number).toList(), dateTime: dateTime, guests: guestCount, note: note));
    if (holdError != null) throw holdError!;

    return Reservation(
      id: 'sim-${holds.length}',
      code: 'DF${9000 + holds.length}',
      customerId: MockData.currentCustomer.id,
      tableIds: tables.map((t) => t.id).toList(),
      tableNumbers: tables.map((t) => t.number).toList(),
      area: tables.first.area,
      capacity: tables.fold(0, (sum, t) => sum + t.capacity),
      dateTime: dateTime,
      guestCount: guestCount,
      note: note,
      holdExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<Reservation> confirm(String reservationId,
      {List<OrderItem> items = const [], PaymentMethod? payment}) async {
    confirms.add((id: reservationId, items: items, payment: payment));
    if (confirmError != null) {
      if (expireOnConfirmError) _expired.add(reservationId);
      throw confirmError!;
    }
    return MockData.reservations.firstWhere((r) => r.id == reservationId).copyWith(
        preOrderItems: items.isEmpty ? null : items,
        preOrderPayment: items.isEmpty ? null : payment,
        clearHold: true);
  }

  @override
  Future<Reservation> cancel(String reservationId) async {
    cancels.add(reservationId);
    if (cancelError != null) throw cancelError!;
    return MockData.reservations
        .firstWhere((r) => r.id == reservationId)
        .copyWith(status: ReservationStatus.cancelled, clearHold: true);
  }
}
