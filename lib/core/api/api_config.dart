import 'package:flutter/foundation.dart';

/// Cấu hình kết nối tới backend Laravel.
/// Backend chạy bằng: php artisan serve (port 8000 mặc định).
class ApiConfig {
  ApiConfig._();

  /// TODO: điền IP LAN máy tính khi chạy trên điện thoại thật.
  /// Ví dụ: 'http://192.168.x.x:8080/api'
  /// Để trống khi chạy emulator/simulator trên máy.
  static const String _kLanOverride = '';

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (_kLanOverride.isNotEmpty) return _kLanOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api'; // Android Emulator → php artisan serve port 8000
    }
    return 'http://127.0.0.1:8000/api'; // Windows desktop → php artisan serve port 8000
  }

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

  static const Duration timeout = Duration(seconds: 15);
}
