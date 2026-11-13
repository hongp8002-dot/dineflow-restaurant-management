import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/session/session_store.dart';
import '../models/user.dart';

/// Đăng nhập / đăng ký / đăng xuất qua API và giữ phiên trong [SessionStore].
class AuthRepository {
  AuthRepository({ApiClient? api, SessionStore? session})
      : _api = api ?? ApiClient.instance,
        _session = session ?? SessionStore.instance;

  /// Instance dùng chung trong app. Không phải `final` để test thay bằng bản dùng backend giả.
  static AuthRepository instance = AuthRepository();

  final ApiClient _api;
  final SessionStore _session;

  /// [identifier] là số điện thoại hoặc email.
  Future<User> login(String identifier, String password) async {
    final res = await _api.post('/login', body: {
      'login': identifier.trim(),
      'password': password,
      'device_name': 'flutter-app',
    });
    return _startSession(res.map);
  }

  Future<User> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await _api.post('/register', body: {
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.replaceAll(RegExp(r'\D'), ''),
      'password': password,
      'device_name': 'flutter-app',
    });
    return _startSession(res.map);
  }

  /// Xóa token trên server (nếu được) rồi xóa phiên trên máy. Luôn đăng xuất được kể cả khi mất mạng.
  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } on ApiException {
      // Mất mạng hoặc token đã hết hạn: vẫn xóa phiên cục bộ.
    }
    await _session.clear();
  }

  /// Tải lại hồ sơ của tài khoản đang đăng nhập (điểm, hạng thành viên...) từ `GET /me`,
  /// vd sau khi thu ngân thanh toán và cộng điểm. Màn nào nghe [SessionStore] sẽ tự vẽ lại.
  /// Lỗi mạng thì giữ hồ sơ đang có, không báo lỗi.
  Future<void> refreshProfile() async {
    if (!_session.isSignedIn) return;
    try {
      final res = await _api.get('/me');
      await _session.updateUser(res.map);
    } on ApiException catch (_) {
      // Giữ hồ sơ cũ; lần mở màn sau sẽ thử lại.
    }
  }

  /// Đổi mật khẩu của tài khoản đang đăng nhập. Server kiểm tra mật khẩu hiện tại;
  /// sai thì ném [ApiException] 422 có `errors['current_password']`.
  /// Đổi xong, token của các máy khác bị thu hồi, máy này vẫn giữ phiên.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _api.patch('/me/password', body: {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': newPassword,
    });
  }

  /// Xác nhận phiên đã lưu còn dùng được. Trả về user mới nhất,
  /// hoặc null nếu phiên hết hạn (phiên cục bộ đã được xóa).
  /// Mất mạng thì giữ nguyên phiên cũ để vào app được.
  Future<User?> restore() async {
    if (!_session.isSignedIn) return null;
    try {
      final res = await _api.get('/me');
      await _session.updateUser(res.map);
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.isForbidden) {
        await _session.clear();
        return null;
      }
    }
    return _session.user;
  }

  // ── Quên mật khẩu (OTP qua email, chỉ tài khoản khách hàng) ─────────────────

  /// Bước 1: xin mã OTP gửi tới [email]. Trả về số giây phải chờ trước khi được gửi lại.
  /// Server luôn trả lời như nhau dù email có tài khoản hay không (chống dò tài khoản).
  Future<({String message, int resendIn})> requestPasswordReset(String email) async {
    final res = await _api.post('/password/forgot', body: {'email': email.trim()});
    return (message: res.message, resendIn: (res.map['resend_in'] as num?)?.toInt() ?? 60);
  }

  /// Bước 2: kiểm tra mã. Sai thì ném [ApiException] 422 kèm số lần thử còn lại.
  Future<void> verifyPasswordResetCode(String email, String code) async {
    await _api.post('/password/verify', body: {'email': email.trim(), 'code': code.trim()});
  }

  /// Bước 3: đặt mật khẩu mới. Thành công thì mọi thiết bị đang đăng nhập tài khoản này bị đăng xuất.
  Future<String> resetPassword({required String email, required String code, required String password}) async {
    final res = await _api.post('/password/reset', body: {
      'email': email.trim(),
      'code': code.trim(),
      'password': password,
      'password_confirmation': password,
    });
    return res.message;
  }

  Future<User> _startSession(Map<String, dynamic> data) async {
    await _session.save(data['token'] as String, data['user'] as Map<String, dynamic>);
    return _session.user!;
  }
}
