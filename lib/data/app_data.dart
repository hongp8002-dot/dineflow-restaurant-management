import '../core/api/api_exception.dart';
import '../core/session/session_store.dart';
import '../models/user.dart';
import 'favorite_store.dart';
import 'invoice_repository.dart';
import 'menu_repository.dart';
import 'mock_data.dart';
import 'order_repository.dart';
import 'report_repository.dart';
import 'reservation_repository.dart';
import 'settings_repository.dart';
import 'table_repository.dart';

/// Nhóm dữ liệu động cần làm mới thường xuyên (khác thực đơn, ít đổi).
enum LiveSource { tables, orders, invoices, reservations, report }

/// Tải dữ liệu thật từ API vào kho dữ liệu mà các màn hình đang đọc ([MockData]).
///
/// Mỗi giai đoạn nối API sẽ thêm phần của mình vào đây (thực đơn, bàn, đơn hàng, hóa đơn...).
/// Màn hình giữ nguyên cách đọc dữ liệu; chỉ nguồn dữ liệu đổi từ dữ liệu mẫu sang server.
class AppData {
  AppData._();

  /// Tải mọi dữ liệu sau khi đăng nhập / mở lại app còn phiên.
  ///
  /// Trả về thông báo lỗi tiếng Việt nếu có phần nào tải thất bại (app vẫn dùng được với
  /// dữ liệu đang có), hoặc null nếu mọi thứ tải xong.
  static Future<String?> load() async {
    final results = await Future.wait([
      _loadMenu(),
      refresh(defaultSources()),
      _loadPromotions(),
      _loadSettings(),
      if (SessionStore.instance.user?.role == UserRole.customer) _loadFavorites(),
    ]);

    final failures = results.whereType<String>().toList();
    return failures.isEmpty ? null : 'Không tải được ${failures.join('; ')}';
  }

  /// Thu ngân và admin được xem hóa đơn; các vai trò khác không (server trả 403) nên không tải.
  static bool get _isCashierSide {
    final role = SessionStore.instance.user?.role;
    return role == UserRole.cashier || role == UserRole.admin;
  }

  /// Các nhóm dữ liệu động cần có với vai trò đang đăng nhập.
  static Set<LiveSource> defaultSources() => {
        LiveSource.tables,
        LiveSource.orders,
        if (_isCashierSide) LiveSource.invoices,
        if (SessionStore.instance.user?.role == UserRole.customer) LiveSource.reservations,
        if (SessionStore.instance.user?.role == UserRole.admin) LiveSource.report,
      };

  static Future<String?> _loadPromotions() async {
    try {
      final promotions = await InvoiceRepository.instance.fetchAvailablePromotions();
      // Mọi vai trò đều xem được: khách (Ví voucher), admin (Khuyến mãi), thu ngân (áp mã khi thanh toán).
      MockData.promotions = promotions;
      MockData.availablePromotions = promotions;
      return null;
    } on ApiException catch (e) {
      return 'khuyến mãi: ${e.message}';
    }
  }

  /// Tài khoản nhận chuyển khoản + quy tắc thành viên (GET /api/settings).
  static Future<String?> _loadSettings() async {
    try {
      await SettingsRepository.instance.load();
      return null;
    } on ApiException catch (e) {
      return 'cấu hình: ${e.message}';
    }
  }

  static Future<String?> _loadMenu() async {
    try {
      final menu = await MenuRepository.instance.fetch();
      MockData.setMenu(categories: menu.categories, foods: menu.foods);
      return null;
    } on ApiException catch (e) {
      return 'thực đơn: ${e.message}';
    }
  }

  /// Tải danh sách món yêu thích vào [FavoriteStore] (chỉ cho khách hàng).
  static Future<String?> _loadFavorites() async {
    try {
      await FavoriteStore.instance.loadFromApi();
      return null;
    } catch (e) {
      return null; // Lỗi yêu thích không ngăn vào app
    }
  }

  /// Tải lại các nhóm dữ liệu động trong [sources], song song với nhau.
  /// Trả về mô tả lỗi (ghép các nhóm lỗi), hoặc null nếu thành công hết.
  /// Nhóm nào lỗi thì giữ nguyên dữ liệu đang có của nhóm đó.
  ///
  /// Nhiều màn hình mở cùng lúc đều xin làm mới cùng một nhóm; mặc định chúng dùng chung một yêu cầu
  /// đang chạy thay vì gửi trùng lặp. Dùng `force: true` ngay SAU KHI thay đổi dữ liệu (tạo đơn, thanh toán)
  /// để chắc chắn có lượt tải mới phản ánh thay đổi đó.
  static Future<String?> refresh(Set<LiveSource> sources, {bool force = false}) async {
    final results = await Future.wait([
      for (final source in sources)
        switch (source) {
          LiveSource.tables => refreshTables(force: force),
          LiveSource.orders => refreshOrders(force: force),
          LiveSource.invoices => refreshInvoices(force: force),
          LiveSource.reservations => refreshReservations(force: force),
          LiveSource.report => refreshReport(force: force),
        },
    ]);

    final failures = results.whereType<String>().toList();
    return failures.isEmpty ? null : failures.join('; ');
  }

  static Future<String?> refreshTables({bool force = false}) => _refreshSource(
        LiveSource.tables,
        force: force,
        label: 'bàn',
        fetch: TableRepository.instance.fetch,
        apply: MockData.setTables,
      );

  static Future<String?> refreshOrders({bool force = false}) => _refreshSource(
        LiveSource.orders,
        force: force,
        label: 'đơn hàng',
        fetch: OrderRepository.instance.fetchAll,
        apply: MockData.setOrders,
      );

  static Future<String?> refreshInvoices({bool force = false}) => _refreshSource(
        LiveSource.invoices,
        force: force,
        label: 'hóa đơn',
        fetch: InvoiceRepository.instance.fetchAll,
        apply: MockData.setInvoices,
      );

  static Future<String?> refreshReservations({bool force = false}) => _refreshSource(
        LiveSource.reservations,
        force: force,
        label: 'lịch đặt bàn',
        fetch: ReservationRepository.instance.fetchMine,
        apply: MockData.setReservations,
      );

  static Future<String?> refreshReport({bool force = false}) => _refreshSource(
        LiveSource.report,
        force: force,
        label: 'báo cáo',
        fetch: ReportRepository.instance.fetchOverview,
        apply: MockData.setReport,
      );

  static final Map<LiveSource, Future<String?>> _inFlight = {};
  static final Map<LiveSource, int> _tickets = {};

  /// Tải một nhóm dữ liệu. Chỉ kết quả của lượt tải MỚI NHẤT được áp dụng, nên một lượt cũ về trễ
  /// (dữ liệu có thể đã lỗi thời) không ghi đè lượt mới.
  static Future<String?> _refreshSource<T>(
    LiveSource source, {
    required bool force,
    required String label,
    required Future<T> Function() fetch,
    required void Function(T data) apply,
  }) {
    if (!force) {
      final running = _inFlight[source];
      if (running != null) return running;
    }

    final ticket = _tickets[source] = (_tickets[source] ?? 0) + 1;
    late final Future<String?> future;
    future = () async {
      try {
        final data = await fetch();
        if (_tickets[source] == ticket) apply(data);
        return null;
      } on ApiException catch (e) {
        return '$label: ${e.message}';
      } finally {
        if (identical(_inFlight[source], future)) _inFlight.remove(source);
      }
    }();
    _inFlight[source] = future;
    return future;
  }
}
