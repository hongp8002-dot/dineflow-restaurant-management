import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/session/session_store.dart';
import '../models/customer.dart';
import '../models/food.dart';
import '../models/food_category.dart';
import '../models/food_option.dart';
import '../models/invoice.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/promotion.dart';
import '../models/reservation.dart';
import '../models/revenue.dart';
import '../models/table_model.dart';
import '../models/user.dart';
import 'loyalty_rules.dart';

/// Toàn bộ dữ liệu mẫu (mock) cho ứng dụng DineFlow.
/// Đây KHÔNG phải dữ liệu thật, chỉ dùng để hiển thị giao diện.
class MockData {
  MockData._();

  // ------------------------- USERS (tài khoản) -------------------------
  static final List<User> users = [
    const User(
      id: 'u1',
      name: 'Nguyễn Văn Admin',
      email: 'admin@dineflow.vn',
      phone: '0901000001',
      role: UserRole.admin,
    ),
    const User(
      id: 'u2',
      name: 'Trần Thị Order',
      email: 'order@dineflow.vn',
      phone: '0901000002',
      role: UserRole.orderStaff,
    ),
    const User(
      id: 'u3',
      name: 'Lê Văn Thu Ngân',
      email: 'cashier@dineflow.vn',
      phone: '0901000003',
      role: UserRole.cashier,
    ),
    const User(
      id: 'u4',
      name: 'Phạm Thị Khách',
      email: 'customer@dineflow.vn',
      phone: '0901000004',
      role: UserRole.customer,
    ),
    const User(
      id: 'u5',
      name: 'Hoàng Văn Bảo',
      email: 'bao.order@dineflow.vn',
      phone: '0901000005',
      role: UserRole.orderStaff,
      status: AccountStatus.locked,
    ),
    const User(
      id: 'u6',
      name: 'Đỗ Thị Mai',
      email: 'mai.cashier@dineflow.vn',
      phone: '0901000006',
      role: UserRole.cashier,
    ),
  ];

  /// Người đang đăng nhập nếu đúng vai trò [role]; không thì dùng tài khoản mẫu [fallback]
  /// (khi chưa đăng nhập thật, ví dụ trong test giao diện).
  static User _signedIn(UserRole role, User fallback) {
    final user = SessionStore.instance.user;
    return (user != null && user.role == role) ? user : fallback;
  }

  static User get currentAdmin => _signedIn(UserRole.admin, users[0]);
  static User get currentOrderStaff => _signedIn(UserRole.orderStaff, users[1]);
  static User get currentCashier => _signedIn(UserRole.cashier, users[2]);
  static User get currentCustomerUser => _signedIn(UserRole.customer, users[3]);

  // ------------------------- FOOD CATEGORIES -------------------------
  static List<FoodCategory> categories = [
    const FoodCategory(id: 'c1', name: 'Cà phê', icon: Icons.coffee),
    const FoodCategory(id: 'c2', name: 'Trà', icon: Icons.emoji_food_beverage),
    const FoodCategory(id: 'c3', name: 'Nước ép', icon: Icons.local_bar),
    const FoodCategory(id: 'c4', name: 'Món chính', icon: Icons.restaurant),
    const FoodCategory(id: 'c5', name: 'Khai vị', icon: Icons.tapas),
    const FoodCategory(id: 'c6', name: 'Tráng miệng', icon: Icons.icecream),
  ];

  // ------------------------- FOOD OPTIONS -------------------------
  static const _sizeOptions = [
    FoodOption(id: 'o_size_s', type: FoodOptionType.size, name: 'Size S', extraPrice: 0),
    FoodOption(id: 'o_size_m', type: FoodOptionType.size, name: 'Size M', extraPrice: 8000),
    FoodOption(id: 'o_size_l', type: FoodOptionType.size, name: 'Size L', extraPrice: 14000),
  ];

  static const _toppingOptions = [
    FoodOption(id: 'o_top_pearl', type: FoodOptionType.topping, name: 'Trân châu', extraPrice: 6000),
    FoodOption(id: 'o_top_pudding', type: FoodOptionType.topping, name: 'Pudding', extraPrice: 7000),
    FoodOption(id: 'o_top_cream', type: FoodOptionType.topping, name: 'Kem cheese', extraPrice: 10000),
  ];

  // ------------------------- FOODS -------------------------
  static const _foodsJsonPath = 'assets/data/foods.json';

  /// Thực đơn, đọc từ [_foodsJsonPath] bằng [loadFoods] lúc mở app.
  static List<Food> foods = const [];

  /// Đọc thực đơn từ `assets/data/foods.json`. Phải gọi (và chờ xong) trước khi
  /// dựng giao diện, vì các màn hình đọc [foods] một cách đồng bộ.
  static Future<void> loadFoods() async {
    final list = jsonDecode(await rootBundle.loadString(_foodsJsonPath)) as List<dynamic>;
    const optionGroups = {'size': _sizeOptions, 'topping': _toppingOptions};
    foods = [for (final json in list) Food.fromJson(json as Map<String, dynamic>, optionGroups)];
  }

  /// Thay thực đơn mẫu bằng thực đơn thật tải từ API (xem `MenuRepository`).
  static void setMenu({required List<FoodCategory> categories, required List<Food> foods}) {
    // Sao ra danh sách mới (sửa được) để màn Admin thêm/xóa tạm trên máy không lỗi.
    MockData.categories = List.of(categories);
    MockData.foods = List.of(foods);
  }

  static List<Food> get bestSellers => foods.where((f) => f.isBestSeller).toList();

  static Food foodById(String id) => foods.firstWhere((f) => f.id == id);

  static FoodCategory categoryById(String id) => categories.firstWhere((c) => c.id == id);

  // ------------------------- TABLES -------------------------
  static List<TableModel> tables = [
    const TableModel(id: 't1', number: 'Bàn 1', area: 'Tầng 1', capacity: 4, status: TableStatus.empty),
    TableModel(
        id: 't2',
        number: 'Bàn 2',
        area: 'Tầng 1',
        capacity: 2,
        status: TableStatus.serving,
        servingSince: DateTime.now().subtract(const Duration(minutes: 35)),
        currentOrderId: 'ord1'),
    const TableModel(id: 't3', number: 'Bàn 3', area: 'Tầng 1', capacity: 6, status: TableStatus.reserved),
    const TableModel(id: 't4', number: 'Bàn 4', area: 'Tầng 1', capacity: 4, status: TableStatus.empty),
    TableModel(
        id: 't5',
        number: 'Bàn 5',
        area: 'Tầng 1',
        capacity: 2,
        status: TableStatus.serving,
        servingSince: DateTime.now().subtract(const Duration(minutes: 12)),
        currentOrderId: 'ord2'),
    const TableModel(id: 't6', number: 'Bàn 6', area: 'Tầng 1', capacity: 4, status: TableStatus.empty),
    const TableModel(id: 't7', number: 'Bàn 7', area: 'Tầng 2', capacity: 4, status: TableStatus.empty),
    TableModel(
        id: 't8',
        number: 'Bàn 8',
        area: 'Tầng 2',
        capacity: 8,
        status: TableStatus.serving,
        servingSince: DateTime.now().subtract(const Duration(minutes: 50)),
        currentOrderId: 'ord3'),
    const TableModel(id: 't9', number: 'Bàn 9', area: 'Tầng 2', capacity: 2, status: TableStatus.reserved),
    const TableModel(id: 't10', number: 'Bàn 10', area: 'Tầng 2', capacity: 4, status: TableStatus.empty),
  ];

  /// Các khu vực, theo thứ tự xuất hiện trong danh sách bàn.
  static List<String> get areas => tables.map((t) => t.area).toSet().toList();

  /// Tăng lên mỗi khi danh sách bàn được thay mới, để các màn đang mở tự dựng lại.
  static final ValueNotifier<int> tablesVersion = ValueNotifier(0);

  /// Thay danh sách bàn bằng dữ liệu mới từ API (xem `AppData.refreshTables`).
  static void setTables(List<TableModel> value) {
    tables = value;
    tablesVersion.value++;
  }

  // ------------------------- ORDERS -------------------------
  /// Đơn mẫu ban đầu; hóa đơn mẫu bên dưới tham chiếu thẳng vào đây để không phụ thuộc vào [orders]
  /// (được thay bằng đơn thật sau khi đăng nhập).
  static final List<Order> _mockOrders = [
    Order(
      id: 'ord1',
      tableNumber: 'Bàn 2',
      staffName: 'Trần Thị Order',
      items: [
        const OrderItem(id: 'oi1', foodId: 'f1', foodName: 'Cà phê sữa đá', price: 29000, quantity: 2),
        const OrderItem(id: 'oi2', foodId: 'f11', foodName: 'Khoai tây chiên', price: 32000, quantity: 1),
      ],
      status: OrderStatus.serving,
      paymentStatus: PaymentStatus.unpaid,
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
    ),
    Order(
      id: 'ord2',
      tableNumber: 'Bàn 5',
      staffName: 'Trần Thị Order',
      items: [
        const OrderItem(id: 'oi3', foodId: 'f9', foodName: 'Cơm sườn nướng', price: 55000, quantity: 2),
        const OrderItem(id: 'oi4', foodId: 'f6', foodName: 'Trà chanh', price: 25000, quantity: 2),
      ],
      status: OrderStatus.preparing,
      paymentStatus: PaymentStatus.unpaid,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    Order(
      id: 'ord3',
      tableNumber: 'Bàn 8',
      staffName: 'Hoàng Văn Bảo',
      items: [
        const OrderItem(
            id: 'oi5', foodId: 'f12', foodName: 'Gà cánh chiên nước mắm', price: 48000, quantity: 3),
        const OrderItem(id: 'oi6', foodId: 'f5', foodName: 'Trà sữa trân châu', price: 35000, quantity: 4),
        const OrderItem(id: 'oi7', foodId: 'f10', foodName: 'Mì Ý sốt bò bằm', price: 65000, quantity: 2),
      ],
      status: OrderStatus.serving,
      paymentStatus: PaymentStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
    ),
    Order(
      id: 'ord4',
      customerName: 'Phạm Thị Khách',
      staffName: 'Đặt qua app',
      items: [
        const OrderItem(id: 'oi8', foodId: 'f4', foodName: 'Trà đào cam sả', price: 39000, quantity: 1),
        const OrderItem(id: 'oi9', foodId: 'f13', foodName: 'Bánh flan', price: 22000, quantity: 2),
      ],
      status: OrderStatus.completed,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
    Order(
      id: 'ord5',
      customerName: 'Phạm Thị Khách',
      staffName: 'Đặt qua app',
      items: [
        const OrderItem(id: 'oi10', foodId: 'f2', foodName: 'Bạc xỉu', price: 32000, quantity: 1),
      ],
      status: OrderStatus.preparing,
      paymentStatus: PaymentStatus.unpaid,
      createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    Order(
      id: 'ord6',
      customerName: 'Phạm Thị Khách',
      staffName: 'Đặt qua app',
      items: [
        const OrderItem(id: 'oi11', foodId: 'f9', foodName: 'Cơm sườn nướng', price: 55000, quantity: 1),
        const OrderItem(id: 'oi12', foodId: 'f7', foodName: 'Nước ép cam', price: 35000, quantity: 1),
      ],
      status: OrderStatus.completed,
      paymentStatus: PaymentStatus.paid,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  /// Danh sách đơn mà các màn hình đọc: ban đầu là đơn mẫu, sau đăng nhập là đơn thật từ API.
  static List<Order> orders = _mockOrders;

  /// Tăng lên mỗi khi danh sách đơn được thay mới, để các màn đang mở tự dựng lại.
  static final ValueNotifier<int> ordersVersion = ValueNotifier(0);

  /// Thay danh sách đơn bằng dữ liệu mới từ API (xem `AppData.refresh`).
  static void setOrders(List<Order> value) {
    orders = value;
    ordersVersion.value++;
  }

  static Order orderById(String id) => orders.firstWhere((o) => o.id == id);

  /// Như [orderById] nhưng trả null nếu không có (vd. bàn trỏ tới đơn chưa được tải về).
  static Order? findOrder(String id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Đơn tại bàn cần thu ngân xử lý: chưa thanh toán và chưa bị hủy.
  static List<Order> get pendingPaymentOrders => orders
      .where((o) => o.paymentStatus == PaymentStatus.unpaid || o.paymentStatus == PaymentStatus.pending)
      .where((o) => o.status != OrderStatus.cancelled)
      .where((o) => o.tableNumber != null)
      // Đơn chưa có món (bàn vừa mở / vừa nhận bàn, chưa order) thì chưa có gì để thu
      .where((o) => o.items.isNotEmpty)
      .toList();

  // ------------------------- CUSTOMERS -------------------------
  static final List<Customer> customers = [
    const Customer(
      id: 'cus1',
      name: 'Phạm Thị Khách',
      phone: '0901000004',
      memberCode: 'DF-000123',
      points: 850,
      tier: MemberTier.gold,
    ),
    const Customer(
      id: 'cus2',
      name: 'Nguyễn Minh Anh',
      phone: '0912345678',
      memberCode: 'DF-000124',
      points: 220,
      tier: MemberTier.silver,
    ),
    const Customer(
      id: 'cus3',
      name: 'Vũ Thành Long',
      phone: '0987654321',
      memberCode: 'DF-000125',
      points: 2100,
      tier: MemberTier.platinum,
    ),
  ];

  /// Hồ sơ thành viên của khách đang đăng nhập (mã thành viên và điểm lấy từ server);
  /// chưa đăng nhập thật thì dùng khách mẫu.
  static Customer get currentCustomer {
    final user = SessionStore.instance.user;
    if (user == null || user.role != UserRole.customer) return customers[0];

    return Customer(
      id: user.id,
      name: user.name,
      phone: user.phone,
      memberCode: user.memberCode ?? '—',
      points: user.points,
      // Hạng tính từ điểm theo quy tắc Kiểu A (data/loyalty_rules.dart): Vàng từ 500, Kim cương từ 1.500.
      tier: LoyaltyRules.tierFor(user.points),
    );
  }

  // ------------------------- RESERVATIONS (đặt bàn) -------------------------
  static List<Reservation> reservations = [
    Reservation(
      id: 'r1',
      code: 'DF7421',
      customerId: 'cus1',
      tableIds: const ['t4'],
      tableNumbers: const ['Bàn 4'],
      area: 'Tầng 1',
      capacity: 4,
      dateTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
      guestCount: 4,
      note: 'Kỷ niệm sinh nhật, xin bàn gần cửa sổ nếu có thể.',
      preOrderItems: const [
        OrderItem(id: 'pre1', foodId: 'f14', foodName: 'Tiramisu', price: 38000, quantity: 1),
        OrderItem(id: 'pre2', foodId: 'f4', foodName: 'Trà đào cam sả', price: 39000, quantity: 4),
      ],
      preOrderPayment: PaymentMethod.qr,
    ),
    Reservation(
      id: 'r2',
      code: 'DF5310',
      customerId: 'cus1',
      tableIds: const ['t10'],
      tableNumbers: const ['Bàn 10'],
      area: 'Tầng 2',
      capacity: 4,
      dateTime: DateTime.now().subtract(const Duration(days: 5)),
      guestCount: 3,
      status: ReservationStatus.completed,
    ),
    Reservation(
      id: 'r3',
      code: 'DF1187',
      customerId: 'cus1',
      tableIds: const ['t6'],
      tableNumbers: const ['Bàn 6'],
      area: 'Tầng 1',
      capacity: 4,
      dateTime: DateTime.now().subtract(const Duration(days: 2)),
      guestCount: 2,
      status: ReservationStatus.cancelled,
    ),
  ];

  /// Tăng lên mỗi khi danh sách đặt bàn thay đổi, để các màn đang mở sẵn trong
  /// khung tab (Trang chủ, Lịch đặt) tự cập nhật.
  static final ValueNotifier<int> reservationsVersion = ValueNotifier(0);

  /// Danh sách đặt bàn sắp tới của khách hàng hiện tại, sắp theo thời gian gần nhất.
  static List<Reservation> get upcomingReservations =>
      reservations.where((r) => r.status == ReservationStatus.upcoming).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  /// Thay toàn bộ danh sách đặt bàn bằng dữ liệu từ API (xem `AppData.refresh`).
  static void setReservations(List<Reservation> value) {
    reservations = value;
    reservationsVersion.value++;
  }

  /// Thêm một lượt đặt bàn, hoặc thay lượt cùng id (sau khi giữ bàn / xác nhận / hủy thành công trên
  /// server), để màn hình cập nhật ngay mà không phải chờ tải lại danh sách.
  static void upsertReservation(Reservation reservation) {
    final updated = [...reservations];
    final index = updated.indexWhere((r) => r.id == reservation.id);
    if (index == -1) {
      updated.insert(0, reservation);
    } else {
      updated[index] = reservation;
    }
    setReservations(updated);
  }

  // ------------------------- PROMOTIONS -------------------------
  /// Khuyến mãi: ban đầu là dữ liệu mẫu, sau đăng nhập được thay bằng danh sách lấy từ server
  /// (`GET /promotions`, chỉ gồm voucher còn hiệu lực) — dùng cho Ví voucher và màn Khuyến mãi.
  static List<Promotion> promotions = [
    Promotion(
      id: 'p1',
      name: 'Ưu đãi khai trương',
      code: 'DINEFLOW10',
      percent: 10,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 10)),
      status: PromotionStatus.active,
    ),
    Promotion(
      id: 'p2',
      name: 'Giảm giá cuối tuần',
      code: 'WEEKEND15',
      percent: 15,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      endDate: DateTime.now().add(const Duration(days: 2)),
      status: PromotionStatus.active,
    ),
    Promotion(
      id: 'p3',
      name: 'Mừng sinh nhật DineFlow',
      code: 'BIRTHDAY20',
      percent: 20,
      startDate: DateTime.now().add(const Duration(days: 15)),
      endDate: DateTime.now().add(const Duration(days: 20)),
      status: PromotionStatus.upcoming,
    ),
    Promotion(
      id: 'p4',
      name: 'Khuyến mãi hè',
      code: 'SUMMER5',
      percent: 5,
      startDate: DateTime.now().subtract(const Duration(days: 40)),
      endDate: DateTime.now().subtract(const Duration(days: 10)),
      status: PromotionStatus.expired,
    ),
  ];

  // ------------------------- INVOICES -------------------------
  static List<Invoice> invoices = [
    Invoice(
      id: 'inv1',
      orderId: 'ord4',
      tableNumber: null,
      items: _mockOrders.firstWhere((o) => o.id == 'ord4').items,
      subtotal: 83000,
      discount: 8300,
      total: 74700,
      paymentMethod: PaymentMethod.qr,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      cashierName: 'Lê Văn Thu Ngân',
    ),
    Invoice(
      id: 'inv2',
      orderId: 'ord6',
      tableNumber: null,
      items: _mockOrders.firstWhere((o) => o.id == 'ord6').items,
      subtotal: 90000,
      discount: 0,
      total: 90000,
      paymentMethod: PaymentMethod.cash,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      cashierName: 'Đỗ Thị Mai',
    ),
  ];

  /// Tăng lên mỗi khi danh sách hóa đơn được thay mới, để các màn đang mở tự dựng lại.
  static final ValueNotifier<int> invoicesVersion = ValueNotifier(0);

  /// Thay danh sách hóa đơn bằng dữ liệu mới từ API (xem `AppData.refresh`).
  static void setInvoices(List<Invoice> value) {
    invoices = value;
    invoicesVersion.value++;
  }

  /// Voucher đang dùng được ở màn thanh toán: ban đầu là các voucher mẫu đang áp dụng,
  /// sau đăng nhập (thu ngân/admin) là voucher còn hiệu lực lấy từ server.
  static List<Promotion> availablePromotions = [
    for (final p in promotions)
      if (p.status == PromotionStatus.active) p,
  ];

  static bool _isToday(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year && time.month == now.month && time.day == now.day;
  }

  /// Hóa đơn đã thu trong hôm nay (mọi thu ngân).
  static List<Invoice> get todayInvoices => invoices.where((i) => _isToday(i.createdAt)).toList();

  /// Hóa đơn hôm nay do thu ngân đang đăng nhập thu — dùng làm "ca" hiện tại.
  static List<Invoice> get myTodayInvoices {
    final me = currentCashier;
    return todayInvoices
        .where((i) => i.cashierId != null ? i.cashierId == me.id : i.cashierName == me.name)
        .toList();
  }

  /// Doanh thu hôm nay, cộng từ các hóa đơn đã thu.
  static double get computedTodayRevenue => todayInvoices.fold(0.0, (sum, i) => sum + i.total);

  /// Số đơn tạo hôm nay (không tính đơn đã hủy).
  static int get computedTodayOrderCount =>
      orders.where((o) => _isToday(o.createdAt) && o.status != OrderStatus.cancelled).length;

  // ------------------------- BÁO CÁO (Admin) -------------------------
  /// Số liệu báo cáo do server tính; [ReportOverview.empty] cho tới khi tải xong.
  static ReportOverview report = ReportOverview.empty;

  /// Tăng lên mỗi khi báo cáo được thay mới, để Dashboard và Báo cáo đang mở tự dựng lại.
  static final ValueNotifier<int> reportVersion = ValueNotifier(0);

  /// Thay báo cáo bằng dữ liệu mới từ API (xem `AppData.refresh`).
  static void setReport(ReportOverview value) {
    report = value;
    reportVersion.value++;
  }
}
