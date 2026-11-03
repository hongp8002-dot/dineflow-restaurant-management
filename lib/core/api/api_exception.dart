/// Lỗi khi gọi API. [message] luôn là câu tiếng Việt có thể hiện thẳng cho người dùng.
class ApiException implements Exception {
  final String message;

  /// Mã HTTP; null nghĩa là không nhận được phản hồi (mất mạng, server tắt, quá thời gian).
  final int? statusCode;

  /// Lỗi theo từng trường khi server trả 422, ví dụ `{ "email": ["..."] }`.
  final Map<String, List<String>> errors;

  const ApiException(this.message, {this.statusCode, this.errors = const {}});

  bool get isNetworkError => statusCode == null;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidation => statusCode == 422;

  @override
  String toString() => message;
}
