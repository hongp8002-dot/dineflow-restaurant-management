import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../session/session_store.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// Phản hồi thành công: `{ status: "success", message, data, meta? }`.
class ApiResponse {
  final dynamic data;
  final String message;
  final Map<String, dynamic> meta;

  const ApiResponse({this.data, this.message = '', this.meta = const {}});

  /// `data` dạng danh sách đối tượng JSON.
  List<Map<String, dynamic>> get list => (data as List<dynamic>).cast<Map<String, dynamic>>();

  /// `data` dạng một đối tượng JSON.
  Map<String, dynamic> get map => data as Map<String, dynamic>;
}

/// Gọi REST API của DineFlow: tự gắn token, giải mã khung phản hồi chung và
/// đổi mọi lỗi thành [ApiException] có thông báo tiếng Việt.
class ApiClient {
  ApiClient({http.Client? client, SessionStore? session, String? baseUrl})
      : _client = client ?? http.Client(),
        _session = session ?? SessionStore.instance,
        _baseUrl = baseUrl;

  /// Instance dùng chung trong app.
  static final ApiClient instance = ApiClient();

  final http.Client _client;
  final SessionStore _session;
  final String? _baseUrl;

  /// Được gọi khi server báo token hết hạn / không hợp lệ (HTTP 401) ở request cần đăng nhập.
  /// App gán hàm này để đưa người dùng về màn Đăng nhập.
  Future<void> Function()? onSessionExpired;

  String get baseUrl => _baseUrl ?? ApiConfig.baseUrl;

  Future<ApiResponse> get(String path, {Map<String, String?>? query}) => _send('GET', path, query: query);

  Future<ApiResponse> post(String path, {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body ?? const {});

  Future<ApiResponse> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body ?? const {});

  Future<ApiResponse> patch(String path, {Map<String, dynamic>? body}) =>
      _send('PATCH', path, body: body ?? const {});

  Future<ApiResponse> delete(String path) => _send('DELETE', path);

  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, String?>? query,
    Map<String, dynamic>? body,
  }) async {
    final params = <String, String>{
      for (final e in (query ?? const <String, String?>{}).entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    };
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params.isEmpty ? null : params);

    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_session.token != null) 'Authorization': 'Bearer ${_session.token}',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(ApiConfig.timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('Máy chủ phản hồi quá lâu. Vui lòng thử lại.');
    } on http.ClientException {
      throw const ApiException('Không kết nối được máy chủ. Kiểm tra mạng hoặc địa chỉ máy chủ.');
    }

    return _decode(response, isLogin: path == '/login' || path == '/register');
  }

  Future<ApiResponse> _decode(http.Response response, {required bool isLogin}) async {
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Không phải JSON (vd. trang lỗi HTML của server) -> xử lý ở dưới.
    }

    final code = response.statusCode;
    final ok = code >= 200 && code < 300 && json != null && json['status'] == 'success';
    if (ok) {
      return ApiResponse(
        data: json['data'],
        message: json['message'] as String? ?? '',
        meta: (json['meta'] as Map<String, dynamic>?) ?? const {},
      );
    }

    // Token hết hạn / bị thu hồi / tài khoản bị khóa giữa chừng.
    if ((code == 401 || code == 403) && !isLogin && _session.isSignedIn) {
      final locked = code == 403 && (json?['message'] as String? ?? '').contains('khóa');
      if (code == 401 || locked) {
        await _session.clear();
        await onSessionExpired?.call();
      }
    }

    final rawErrors = json?['errors'];
    final errors = <String, List<String>>{
      if (rawErrors is Map<String, dynamic>)
        for (final e in rawErrors.entries)
          e.key: (e.value as List<dynamic>).map((v) => v.toString()).toList(),
    };

    throw ApiException(
      json?['message'] as String? ?? 'Máy chủ gặp lỗi ($code). Vui lòng thử lại sau.',
      statusCode: code,
      errors: errors,
    );
  }
}
