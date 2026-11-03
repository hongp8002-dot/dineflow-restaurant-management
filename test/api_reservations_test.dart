import 'dart:convert';

import 'package:dineflow/core/api/api_client.dart';
import 'package:dineflow/core/api/api_exception.dart';
import 'package:dineflow/core/session/session_store.dart';
import 'package:dineflow/data/app_data.dart';
import 'package:dineflow/data/mock_data.dart';
import 'package:dineflow/data/reservation_repository.dart';
import 'package:dineflow/models/food_option.dart';
import 'package:dineflow/models/invoice.dart';
import 'package:dineflow/models/order_item.dart';
import 'package:dineflow/models/reservation.dart';
import 'package:dineflow/models/table_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _reservationJson(
  int id, {
  String status = 'upcoming',
  String? holdExpiresAt,
  List<Map<String, Object?>> preOrder = const [],
  String? payment,
  List<int> tableIds = const [11, 12],
}) =>
    {
      'id': id,
      'code': 'DF-${1000 + id}',
      'customer_id': 4,
      'table_ids': tableIds,
      'table_numbers': [for (final t in tableIds) 'Bàn $t'],
      'area': 'Ngoài trời',
      'capacity': 10,
      'date_time': '2025-10-12T19:00:00+07:00',
      'guest_count': 8,
      'note': 'Sinh nhật',
      'status': status,
      'status_label': 'x',
      'is_held': holdExpiresAt != null,
      'hold_expires_at': holdExpiresAt,
      'pre_order_items': preOrder,
      'pre_order_payment': payment,
      'pre_order_total': 0,
    };

http.Response _json(int code, Object? data, {String status = 'success', String message = 'OK'}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode({'status': status, 'message': message, 'data': data})),
      code,
      headers: {'content-type': 'application/json'},
    );

ReservationRepository _repo(Future<http.Response> Function(http.Request) handler) => ReservationRepository(
      api: ApiClient(client: MockClient(handler), session: SessionStore(), baseUrl: 'http://test/api'),
    );

const _table11 = TableModel(id: '11', number: 'Bàn 11', area: 'Ngoài trời', capacity: 4);
const _table12 = TableModel(id: '12', number: 'Bàn 12', area: 'Ngoài trời', capacity: 6);

void main() {
  late List<Reservation> originalReservations;
  late ReservationRepository originalRepo;

  setUp(() {
    originalReservations = MockData.reservations;
    originalRepo = ReservationRepository.instance;
  });

  tearDown(() {
    MockData.setReservations(originalReservations);
    ReservationRepository.instance = originalRepo;
  });

  group('Reservation.fromApiJson', () {
    test('lượt đặt đã xác nhận có món đặt trước (dòng món được đánh số, kèm tùy chọn)', () {
      final r = Reservation.fromApiJson(_reservationJson(
        7,
        payment: 'qr',
        preOrder: [
          {
            'food_id': 9,
            'food_name': 'Cơm sườn nướng',
            'quantity': 2,
            'price': 55000,
            'options': [
              {'id': 3, 'group': 'size', 'name': 'Size L', 'price_modifier': 14000},
            ],
            'note': 'Không hành',
          },
          {'food_id': 12, 'food_name': 'Gà cánh', 'quantity': 1, 'price': 48000, 'options': [], 'note': null},
        ],
      ));

      expect(r.id, '7');
      expect(r.code, 'DF-1007');
      expect(r.customerId, '4');
      expect(r.tableIds, ['11', '12']);
      expect(r.tableNumbers, ['Bàn 11', 'Bàn 12']);
      expect(r.tableNumber, 'Bàn 11 + Bàn 12');
      expect(r.isMerged, isTrue);
      expect(r.capacity, 10);
      expect(r.dateTime.toUtc(), DateTime.utc(2025, 10, 12, 12, 0));
      expect(r.status, ReservationStatus.upcoming);
      expect(r.isHeld, isFalse);

      expect(r.preOrderPayment, PaymentMethod.qr);
      expect(r.preOrderItems.map((i) => i.id), ['pre-0', 'pre-1']);
      expect(r.preOrderItems.first.selectedOptions.single.type, FoodOptionType.size);
      expect(r.preOrderItems.first.total, (55000 + 14000) * 2);
      expect(r.preOrderQuantity, 3);
      expect(r.preOrderTotal, (55000 + 14000) * 2 + 48000);
    });

    test('lượt đang giữ bàn có hạn giữ; đã hủy / hoàn thành đọc đúng trạng thái', () {
      final held = Reservation.fromApiJson(_reservationJson(1, holdExpiresAt: '2025-10-12T10:10:00+07:00'));
      expect(held.isHeld, isTrue);
      expect(held.holdExpiresAt!.toUtc(), DateTime.utc(2025, 10, 12, 3, 10));

      expect(Reservation.fromApiJson(_reservationJson(2, status: 'cancelled')).status,
          ReservationStatus.cancelled);
      expect(Reservation.fromApiJson(_reservationJson(3, status: 'completed')).status,
          ReservationStatus.completed);
      expect(Reservation.fromApiJson(_reservationJson(4)).preOrderItems, isEmpty);
    });

    test('copyWith(clearHold) gỡ hạn giữ bàn, còn lại giữ nguyên hạn', () {
      final held = Reservation.fromApiJson(_reservationJson(1, holdExpiresAt: '2025-10-12T10:10:00+07:00'));

      expect(held.copyWith(status: ReservationStatus.cancelled).isHeld, isTrue);
      expect(held.copyWith(clearHold: true).isHeld, isFalse);
    });
  });

  group('ReservationRepository', () {
    test('hold gửi bàn (id số), giờ UTC, số khách, ghi chú và cờ giữ bàn', () async {
      late http.Request seen;
      final repo = _repo((req) async {
        seen = req;
        return _json(201, _reservationJson(7, holdExpiresAt: '2025-10-12T10:10:00+07:00'));
      });
      final at = DateTime(2025, 10, 12, 19, 0); // giờ địa phương

      final r =
          await repo.hold(tables: [_table11, _table12], dateTime: at, guestCount: 8, note: '  Sinh nhật ');

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/reservations');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['table_ids'], [11, 12]);
      expect(body['guest_count'], 8);
      expect(body['note'], 'Sinh nhật');
      expect(body['hold'], true);
      // Giờ gửi dạng UTC có hậu tố Z, quy đổi đúng về giờ đã chọn
      expect(body['date_time'], endsWith('Z'));
      expect(DateTime.parse(body['date_time'] as String).toLocal(), at);
      expect(r.isHeld, isTrue);
    });

    test('hold không gửi ghi chú rỗng', () async {
      late Map<String, dynamic> body;
      final repo = _repo((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(201, _reservationJson(7));
      });

      await repo.hold(tables: [_table11], dateTime: DateTime(2025, 10, 12, 19), guestCount: 2, note: '   ');

      expect(body.containsKey('note'), isFalse);
    });

    test('confirm: có món thì gửi món + phương thức; không món thì chỉ xác nhận (không đụng món đã có)',
        () async {
      final bodies = <Map<String, dynamic>>[];
      final paths = <String>[];
      final repo = _repo((req) async {
        paths.add(req.url.path);
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return _json(200, _reservationJson(7));
      });
      const item = OrderItem(
        id: 'x',
        foodId: '9',
        foodName: 'Cơm sườn nướng',
        price: 0,
        quantity: 2,
        selectedOptions: [FoodOption(id: '3', type: FoodOptionType.size, name: 'Size L')],
        note: 'Không hành',
      );

      await repo.confirm('7', items: [item], payment: PaymentMethod.qr);
      await repo.confirm('7');

      expect(paths, everyElement('/api/reservations/7/confirm'));
      expect(bodies[0], {
        'pre_order_items': [
          {
            'food_id': 9,
            'quantity': 2,
            'option_ids': [3],
            'note': 'Không hành',
          },
        ],
        'pre_order_payment': 'qr',
      });
      expect(bodies[1], isEmpty);
    });

    test('cancel gọi PATCH /reservations/{id}/cancel; fetchMine đọc danh sách', () async {
      final calls = <String>[];
      final repo = _repo((req) async {
        calls.add('${req.method} ${req.url.path}');
        return req.url.path.endsWith('/my')
            ? _json(200, [_reservationJson(2), _reservationJson(1, status: 'cancelled')])
            : _json(200, _reservationJson(7, status: 'cancelled'));
      });

      final cancelled = await repo.cancel('7');
      final mine = await repo.fetchMine();

      expect(calls, ['PATCH /api/reservations/7/cancel', 'GET /api/reservations/my']);
      expect(cancelled.status, ReservationStatus.cancelled);
      expect(mine.map((r) => r.id), ['2', '1']);
    });

    test('id không phải số (dữ liệu mẫu) bị chặn trước khi gọi mạng', () async {
      var calls = 0;
      final repo = _repo((_) async {
        calls++;
        return _json(200, _reservationJson(1));
      });
      const sampleTable = TableModel(id: 't1', number: 'Bàn 1', area: 'Tầng 1', capacity: 4);

      await expectLater(
        repo.hold(tables: [sampleTable], dateTime: DateTime(2030), guestCount: 2),
        throwsA(isA<ApiException>()),
      );
      await expectLater(repo.confirm('r1'), throwsA(isA<ApiException>()));
      await expectLater(repo.cancel('r1'), throwsA(isA<ApiException>()));
      expect(calls, 0);
    });

    test('server từ chối giữ bàn (trùng giờ) -> ApiException mang lời server', () async {
      final repo = _repo((_) async =>
          _json(422, null, status: 'error', message: 'Bàn 11 đã có người đặt trong khung giờ này.'));

      await expectLater(
        repo.hold(tables: [_table11], dateTime: DateTime(2030, 1, 1, 19), guestCount: 2),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 422)
            .having((e) => e.message, 'message', contains('đã có người đặt'))),
      );
    });
  });

  group('Danh sách đặt bàn trong app', () {
    test('upsertReservation thêm lượt mới lên đầu, thay lượt cùng id, và báo cho màn hình đang mở', () {
      final base = MockData.reservations.length;
      final before = MockData.reservationsVersion.value;

      final created =
          Reservation.fromApiJson(_reservationJson(50, holdExpiresAt: '2030-01-01T10:00:00+07:00'));
      MockData.upsertReservation(created);
      expect(MockData.reservations.length, base + 1);
      expect(MockData.reservations.first.id, '50');
      expect(MockData.reservations.first.isHeld, isTrue);

      MockData.upsertReservation(created.copyWith(status: ReservationStatus.cancelled, clearHold: true));
      expect(MockData.reservations.length, base + 1); // thay thế, không thêm trùng
      expect(MockData.reservations.first.status, ReservationStatus.cancelled);
      expect(MockData.reservations.first.isHeld, isFalse);

      expect(MockData.reservationsVersion.value, before + 2);
    });

    test('AppData.refreshReservations thay danh sách từ server; lỗi mạng thì giữ nguyên', () async {
      ReservationRepository.instance =
          _repo((_) async => _json(200, [_reservationJson(2), _reservationJson(1)]));
      expect(await AppData.refreshReservations(force: true), isNull);
      expect(MockData.reservations.map((r) => r.id), ['2', '1']);

      ReservationRepository.instance = _repo((_) async => throw http.ClientException('offline'));
      final kept = MockData.reservations;
      expect(await AppData.refreshReservations(force: true), startsWith('lịch đặt bàn:'));
      expect(MockData.reservations, same(kept));
    });
  });
}
