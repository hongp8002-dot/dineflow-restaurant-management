import 'package:intl/intl.dart';

/// Các hàm định dạng dùng chung: tiền tệ, ngày giờ.
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currencyFormat = NumberFormat.decimalPattern('vi_VN');

  /// Định dạng số tiền theo kiểu Việt Nam, ví dụ: 45.000đ
  static String currency(num amount) {
    return '${_currencyFormat.format(amount)}đ';
  }

  static String date(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String time(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('HH:mm dd/MM/yyyy').format(date);
  }

  /// Giờ và ngày ngăn bằng dấu chấm giữa, vd: "17:52 · 05/10/2026".
  static String timeDate(DateTime date) => '${time(date)} · ${DateFormat('dd/MM/yyyy').format(date)}';

  /// Mã bàn hai chữ số dùng trên ô bàn, vd: "Bàn 2" -> "02", "Bàn 10" -> "10".
  /// Tên bàn không có số thì giữ nguyên.
  static String tableCode(String tableNumber) {
    final match = RegExp(r'\d+').firstMatch(tableNumber);
    return match == null ? tableNumber : match.group(0)!.padLeft(2, '0');
  }

  static const _weekdayNames = [
    'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật', //
  ];
  static const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// Tên thứ đầy đủ, vd: "Thứ Sáu".
  static String weekdayName(DateTime date) => _weekdayNames[date.weekday - 1];

  /// Tên thứ rút gọn, vd: "T6", "CN".
  static String weekdayShort(DateTime date) => _weekdayShort[date.weekday - 1];

  /// Ngày kèm thứ, vd: "Thứ Sáu, 09/10".
  static String weekdayDate(DateTime date) => '${weekdayName(date)}, ${DateFormat('dd/MM').format(date)}';

  /// Ngày rút gọn kèm thứ, vd: "T6 09/10".
  static String shortWeekdayDate(DateTime date) =>
      '${weekdayShort(date)} ${DateFormat('dd/MM').format(date)}';

  /// Thời gian tương đối, vd: "Vừa xong", "5 phút trước", "2 giờ trước", "Hôm qua".
  static String relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}
