import 'dart:convert';

import 'package:dineflow/core/api/api_client.dart';
import 'package:dineflow/core/api/api_exception.dart';
import 'package:dineflow/core/session/session_store.dart';
import 'package:dineflow/data/auth_repository.dart';
import 'package:dineflow/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phản hồi mẫu giống hệt định dạng backend Laravel trả về.
String _envelope(
    {String status = 'success', String message = 'OK', Object? data, Map<String, dynamic>? errors}) {
  return jsonEncode({
    'status': status,
    'message': message,
    'data': data,
    if (errors != null) 'errors': errors,
  });
}

http.Response _json(int code, String body) => http.Response.bytes(utf8.encode(body), code,
    headers: {'content-type': 'application/json; charset=utf-8'});

const _staffJson = {
  'id': 2,
  'name': 'Nguyễn Văn Order',
  'email': 'staff@dineflow.com',
  'phone': '0900000002',
  'role': 'order_staff',
  'status': 'active',
  'avatar_url': null,
};

void main() {
  late SessionStore session;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session = SessionStore();
  });

  ApiClient clientFor(MockClient mock) =>
      ApiClient(client: mock, session: session, baseUrl: 'http://test/api');

  group('User.fromApiJson', () {
    test('đổi đúng vai trò, id số thành chuỗi và trạng thái khóa', () {
      final user = User.fromApiJson(_staffJson);
      expect(user.id, '2');
      expect(user.role, UserRole.orderStaff);
      expect(user.status, AccountStatus.active);

      expect(User.fromApiJson({..._staffJson, 'role': 'cashier'}).role, UserRole.cashier);
      expect(User.fromApiJson({..._staffJson, 'role': 'admin'}).role, UserRole.admin);
      expect(User.fromApiJson({..._staffJson, 'role': 'customer'}).role, UserRole.customer);
      expect(User.fromApiJson({..._staffJson, 'status': 'locked'}).status, AccountStatus.locked);
    });

    test('thiếu trường tùy chọn vẫn dựng được', () {
      final user = User.fromApiJson({'id': 9, 'role': 'customer'});
      expect(user.name, '');
      expect(user.phone, '');
      expect(user.avatarUrl, isNull);
    });
  });

  group('ApiClient', () {
    test('gắn header, bỏ query rỗng và giải mã khung success', () async {
      await session.save('tok123', _staffJson);
      late http.BaseRequest seen;
      final api = clientFor(MockClient((req) async {
        seen = req;
        return _json(
            200,
            _envelope(data: [
              {'id': 1}
            ], message: 'Xong'));
      }));

      final res = await api.get('/foods', query: {'category_id': '3', 'search': '', 'x': null});

      expect(seen.url.toString(), 'http://test/api/foods?category_id=3');
      expect(seen.headers['Authorization'], 'Bearer tok123');
      expect(seen.headers['Accept'], 'application/json');
      expect(res.message, 'Xong');
      expect(res.list.single['id'], 1);
    });

    test('gửi body JSON cho POST và đọc được tiếng Việt có dấu', () async {
      String? sentBody;
      final api = clientFor(MockClient((req) async {
        sentBody = req.body;
        return _json(200, _envelope(message: 'Đăng nhập thành công.', data: {'ok': true}));
      }));

      final res = await api.post('/login', body: {'login': '0900000002'});

      expect(jsonDecode(sentBody!), {'login': '0900000002'});
      expect(res.message, 'Đăng nhập thành công.');
    });

    test('lỗi 422 mang message và errors theo trường', () async {
      final api = clientFor(MockClient((_) async => _json(
            422,
            _envelope(status: 'error', message: 'Email đã tồn tại.', errors: {
              'email': ['Email đã tồn tại.'],
            }),
          )));

      await expectLater(
        api.post('/register', body: {}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Email đã tồn tại.')
            .having((e) => e.isValidation, 'isValidation', true)
            .having((e) => e.errors['email'], 'errors', ['Email đã tồn tại.'])),
      );
    });

    test('mất kết nối thành ApiException thân thiện, không có statusCode', () async {
      final api = clientFor(MockClient((_) async => throw http.ClientException('connection refused')));

      await expectLater(
        api.get('/foods'),
        throwsA(isA<ApiException>().having((e) => e.isNetworkError, 'isNetworkError', true)),
      );
    });

    test('phản hồi không phải JSON (trang lỗi 500) vẫn ra ApiException', () async {
      final api = clientFor(MockClient((_) async => http.Response('<html>Server Error</html>', 500)));

      await expectLater(
        api.get('/foods'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('401 khi đang đăng nhập: xóa phiên và báo onSessionExpired', () async {
      await session.save('old', _staffJson);
      var expired = 0;
      final api = clientFor(
          MockClient((_) async => _json(401, _envelope(status: 'error', message: 'Chưa đăng nhập.'))))
        ..onSessionExpired = () async => expired++;

      await expectLater(
          api.get('/orders'), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', true)));

      expect(session.isSignedIn, isFalse);
      expect(expired, 1);
    });

    test('đăng nhập sai mật khẩu (401) KHÔNG bị coi là phiên hết hạn', () async {
      var expired = 0;
      final api =
          clientFor(MockClient((_) async => _json(401, _envelope(status: 'error', message: 'Sai mật khẩu.'))))
            ..onSessionExpired = () async => expired++;

      await expectLater(api.post('/login', body: {}), throwsA(isA<ApiException>()));
      expect(expired, 0);
    });

    test('403 vì sai vai trò thì giữ nguyên phiên; 403 vì tài khoản bị khóa thì đăng xuất', () async {
      await session.save('tok', _staffJson);
      var expired = 0;
      var message = 'Vai trò của bạn không được phép thực hiện thao tác này.';
      final api = clientFor(MockClient((_) async => _json(403, _envelope(status: 'error', message: message))))
        ..onSessionExpired = () async => expired++;

      await expectLater(api.post('/orders/1/pay', body: {}), throwsA(isA<ApiException>()));
      expect(session.isSignedIn, isTrue);
      expect(expired, 0);

      message = 'Tài khoản của bạn đã bị khóa.';
      await expectLater(api.get('/orders'), throwsA(isA<ApiException>()));
      expect(session.isSignedIn, isFalse);
      expect(expired, 1);
    });
  });

  group('AuthRepository', () {
    AuthRepository repoFor(MockClient mock) => AuthRepository(api: clientFor(mock), session: session);

    test('login gửi `login`+mật khẩu rồi lưu token và user', () async {
      Map<String, dynamic>? sent;
      final repo = repoFor(MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(200, _envelope(data: {'token': '5|abc', 'token_type': 'Bearer', 'user': _staffJson}));
      }));

      final user = await repo.login(' 0900 000 002 ', '123456');

      expect(sent!['login'], '0900 000 002'); // chỉ trim, backend tự chuẩn hóa số điện thoại
      expect(sent!['password'], '123456');
      expect(user.role, UserRole.orderStaff);
      expect(session.token, '5|abc');
      expect(session.isSignedIn, isTrue);
    });

    test('login sai: ném ApiException và không lưu phiên', () async {
      final repo = repoFor(MockClient((_) async => _json(401, _envelope(status: 'error', message: 'Sai.'))));

      await expectLater(repo.login('x', 'y'), throwsA(isA<ApiException>()));
      expect(session.isSignedIn, isFalse);
    });

    test('register chỉ gửi số trong số điện thoại', () async {
      Map<String, dynamic>? sent;
      final repo = repoFor(MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(
            201,
            _envelope(data: {
              'token': 't',
              'user': {..._staffJson, 'role': 'customer'}
            }));
      }));

      final user =
          await repo.register(name: ' An ', email: 'an@x.com', phone: '0912 345.678', password: 'matkhau');

      expect(sent!['phone'], '0912345678');
      expect(sent!['name'], 'An');
      expect(user.role, UserRole.customer);
    });

    test('logout xóa phiên cục bộ kể cả khi mất mạng', () async {
      await session.save('tok', _staffJson);
      final repo = repoFor(MockClient((_) async => throw http.ClientException('offline')));

      await repo.logout();

      expect(session.isSignedIn, isFalse);
    });

    test('restore: phiên còn hạn thì cập nhật user; hết hạn thì xóa; mất mạng thì giữ', () async {
      await session.save('tok', _staffJson);

      final ok =
          repoFor(MockClient((_) async => _json(200, _envelope(data: {..._staffJson, 'name': 'Tên mới'}))));
      expect((await ok.restore())!.name, 'Tên mới');

      final offline = repoFor(MockClient((_) async => throw http.ClientException('offline')));
      expect(await offline.restore(), isNotNull);
      expect(session.isSignedIn, isTrue);

      final expired =
          repoFor(MockClient((_) async => _json(401, _envelope(status: 'error', message: 'Hết hạn'))));
      expect(await expired.restore(), isNull);
      expect(session.isSignedIn, isFalse);
    });

    test('restore khi chưa đăng nhập không gọi mạng', () async {
      var calls = 0;
      final repo = repoFor(MockClient((_) async {
        calls++;
        return _json(200, _envelope());
      }));

      expect(await repo.restore(), isNull);
      expect(calls, 0);
    });
  });

  group('Đổi mật khẩu', () {
    test('gửi PATCH /me/password đủ 3 trường', () async {
      await session.save('tok', _staffJson);
      late http.Request seen;
      final repo = AuthRepository(
          api: clientFor(MockClient((req) async {
            seen = req;
            return _json(200, _envelope(message: 'Đổi mật khẩu thành công.'));
          })),
          session: session);

      await repo.changePassword(currentPassword: '123456', newPassword: 'moi1234');

      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/api/me/password');
      expect(jsonDecode(seen.body), {
        'current_password': '123456',
        'password': 'moi1234',
        'password_confirmation': 'moi1234',
      });
      expect(session.isSignedIn, isTrue); // máy này vẫn giữ phiên
    });

    test('sai mật khẩu hiện tại: ném ApiException có lỗi theo trường', () async {
      await session.save('tok', _staffJson);
      final repo = AuthRepository(
          api: clientFor(MockClient((req) async => _json(
              422,
              _envelope(status: 'error', message: 'Mật khẩu hiện tại không đúng.', errors: {
                'current_password': ['Mật khẩu hiện tại không đúng.']
              })))),
          session: session);

      await expectLater(
        repo.changePassword(currentPassword: 'sai', newPassword: 'moi1234'),
        throwsA(isA<ApiException>()
            .having((e) => e.isValidation, 'isValidation', isTrue)
            .having((e) => e.errors['current_password'], 'errors', ['Mật khẩu hiện tại không đúng.'])),
      );
    });
  });

  test('SessionStore lưu và khôi phục phiên qua lần mở app sau', () async {
    await session.save('tok', _staffJson);

    final reopened = SessionStore();
    await reopened.load();

    expect(reopened.token, 'tok');
    expect(reopened.user!.email, 'staff@dineflow.com');

    await reopened.clear();
    final again = SessionStore();
    await again.load();
    expect(again.isSignedIn, isFalse);
  });
}
