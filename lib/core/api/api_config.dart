import 'package:flutter/foundation.dart';

/// Cấu hình kết nối tới backend Laravel.
///
/// Mặc định tự chọn theo nền tảng:
/// - Android Emulator: `10.0.2.2` là địa chỉ máy tính chạy emulator.
/// - Còn lại (Windows, Web, iOS Simulator): `127.0.0.1`.
///
/// Điện thoại thật hoặc server khác: truyền địa chỉ khi chạy app, ví dụ
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api`
/// (và chạy server bằng `php artisan serve --host=0.0.0.0`).
class ApiConfig {
  ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  /// Server dev thường đặt `APP_URL=http://127.0.0.1:8000`, nên link ảnh nó trả về trỏ vào
  /// `127.0.0.1` — trên emulator đó là chính emulator, không phải máy chạy server.
  /// Hàm này đổi địa chỉ "local" đó thành địa chỉ máy chủ app đang dùng ([baseUrl]).
  /// Link tới host khác (CDN, S3...) và đường dẫn tương đối được giữ nguyên.
  static String resolveMediaUrl(String url) {
    final media = Uri.tryParse(url);
    if (media == null || !media.hasScheme || !_localHosts.contains(media.host)) return url;

    final base = Uri.parse(baseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: media.path,
      query: media.hasQuery ? media.query : null,
    ).toString();
  }

  static const _localHosts = {'localhost', '127.0.0.1', '10.0.2.2', '0.0.0.0'};

  /// Quá thời gian này mà server chưa trả lời thì báo lỗi.
  static const Duration timeout = Duration(seconds: 15);
}
