import '../core/api/api_client.dart';
import '../models/shift.dart';

/// Quản lý ca làm việc (thu ngân).
class ShiftRepository {
  ShiftRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static ShiftRepository instance = ShiftRepository();

  final ApiClient _api;

  /// Lấy ca đang mở của thu ngân hiện tại.
  /// Trả về null nếu chưa mở ca.
  Future<Shift?> fetchCurrent() async {
    final res = await _api.get('/shifts/current');
    // Server trả data: null khi chưa có ca đang mở
    if (res.data == null) return null;
    return Shift.fromApiJson(res.map);
  }

  /// Admin: các ca mở trong ngày [date], mới nhất trước (báo cáo ca).
  Future<List<Shift>> fetchByDate(DateTime date) async {
    final day = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final res = await _api.get('/shifts', query: {'date': day});
    return [for (final s in res.list) Shift.fromApiJson(s)];
  }

  /// Mở ca mới với số tiền đầu ca.
  Future<Shift> openShift({required double openingCash}) async {
    final res = await _api.post('/shifts', body: {
      'opening_cash': openingCash,
    });
    return Shift.fromApiJson(res.map);
  }

  /// Đóng ca: nhập tiền mặt đếm được.
  Future<Shift> closeShift({
    required String shiftId,
    required double closingCashCounted,
  }) async {
    final id = int.tryParse(shiftId);
    if (id == null) throw Exception('ID ca không hợp lệ');
    final res = await _api.patch('/shifts/$id/close', body: {
      'closing_cash_counted': closingCashCounted,
    });
    return Shift.fromApiJson(res.map);
  }
}
