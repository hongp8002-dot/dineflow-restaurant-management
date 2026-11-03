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
