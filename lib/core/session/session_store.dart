import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';

/// Phiên đăng nhập hiện tại: token Sanctum + hồ sơ người dùng.
///
/// Lưu bằng shared_preferences để mở lại app vẫn còn đăng nhập.
/// Lưu ý: shared_preferences không mã hóa. Khi phát hành thật nên chuyển token
/// sang flutter_secure_storage.
class SessionStore extends ChangeNotifier {
  SessionStore();

  static final SessionStore instance = SessionStore();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  String? _token;
  User? _user;

  String? get token => _token;
  User? get user => _user;
  bool get isSignedIn => _token != null && _user != null;

  /// Đọc phiên đã lưu (gọi một lần lúc mở app).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final rawUser = prefs.getString(_userKey);

    if (token == null || rawUser == null) return;

    try {
      _user = User.fromApiJson(jsonDecode(rawUser) as Map<String, dynamic>);
      _token = token;
    } catch (_) {
      // Dữ liệu cũ/hỏng: coi như chưa đăng nhập.
      await clear();
    }
    notifyListeners();
  }

  /// Lưu phiên sau khi đăng nhập / đăng ký thành công. [userJson] là JSON `user` do API trả về.
  Future<void> save(String token, Map<String, dynamic> userJson) async {
    _token = token;
    _user = User.fromApiJson(userJson);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(userJson));
    notifyListeners();
  }

  /// Cập nhật hồ sơ (vd. sau khi gọi /me) mà giữ nguyên token.
  Future<void> updateUser(Map<String, dynamic> userJson) async {
    if (_token == null) return;
    _user = User.fromApiJson(userJson);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userJson));
    notifyListeners();
  }

  Future<void> clear() async {
    _token = null;
    _user = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }
}
