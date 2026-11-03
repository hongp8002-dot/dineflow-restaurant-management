import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../models/customer.dart';

/// Tra cứu thành viên (dùng cho màn Quét QR của Thu ngân).
class MemberRepository {
  MemberRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static MemberRepository instance = MemberRepository();

  final ApiClient _api;

  /// Tra khách theo mã thẻ/QR.
  /// Trả [Customer] nếu tìm thấy.
  /// Ném [ApiException] với message tiếng Việt nếu không tìm thấy.
  Future<Customer> lookupByCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    final res = await _api.get('/members/$trimmed');
    final json = res.map;
    return Customer(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      memberCode: json['member_code'] as String? ?? trimmed,
      points: (json['points'] as num?)?.toInt() ?? 0,
      tier: _parseTier(json['tier'] as String?),
    );
  }

  static MemberTier _parseTier(String? value) => switch (value) {
        'gold'     => MemberTier.gold,
        'platinum' => MemberTier.platinum,
        _          => MemberTier.silver,
      };
}
