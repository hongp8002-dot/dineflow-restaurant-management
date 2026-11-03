import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../models/reservation.dart';
import '../models/user.dart';
import '../screens/admin/account_management_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/menu_management_screen.dart';
import '../screens/admin/promotion_management_screen.dart';
import '../screens/admin/revenue_report_screen.dart';
import '../screens/admin/table_area_management_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/cashier/cashier_profile_screen.dart';
import '../screens/cashier/cashier_settings_screen.dart';
import '../screens/cashier/cashier_shell.dart';
import '../screens/cashier/history_screen.dart';
import '../screens/cashier/invoice_screen.dart';
import '../screens/cashier/payment_screen.dart';
import '../screens/cashier/scan_member_screen.dart';
import '../screens/cashier/pending_payment_screen.dart';
import '../screens/cashier/shift_screen.dart';
import '../screens/customer/booking_confirmation_screen.dart';
import '../screens/customer/booking_payment_screen.dart';
import '../screens/customer/booking_table_screen.dart';
import '../screens/customer/customer_help_screen.dart';
import '../screens/customer/customer_profile_screen.dart';
import '../screens/customer/customer_settings_screen.dart';
import '../screens/customer/customer_store_location_screen.dart';
import '../screens/customer/favorite_foods_screen.dart';
import '../screens/customer/voucher_wallet_screen.dart';
import '../screens/customer/customer_shell.dart';
import '../screens/customer/food_detail_screen.dart';
import '../screens/customer/member_qr_screen.dart';
import '../screens/customer/menu_screen.dart';
import '../screens/customer/my_bookings_screen.dart';
import '../screens/customer/order_detail_screen.dart';
import '../screens/customer/order_history_screen.dart';
import '../screens/customer/pre_order_screen.dart';
import '../screens/order_staff/create_order_screen.dart';
import '../screens/order_staff/merge_table_screen.dart';
import '../screens/order_staff/order_staff_shell.dart';
import '../screens/order_staff/serving_orders_screen.dart';
import '../screens/order_staff/staff_profile_screen.dart';
import '../screens/order_staff/staff_settings_screen.dart';
import '../screens/order_staff/table_detail_screen.dart';
import '../screens/order_staff/transfer_table_screen.dart';

/// Tên các route dùng trong toàn bộ ứng dụng.
/// Phần định tuyến (onGenerateRoute) được cấu hình ở cuối file này.
class AppRoutes {
  AppRoutes._();

  // Auth
  static const login = '/login';
  static const register = '/register';

  // Customer
  static const customerHome = '/customer/home';
  static const customerMenu = '/customer/menu';
  static const customerFoodDetail = '/customer/food-detail';
  static const customerBooking = '/customer/booking';
  static const customerPreOrder = '/customer/pre-order';
  static const customerBookingPayment = '/customer/booking-payment';
  static const customerBookingConfirmation = '/customer/booking-confirmation';
  static const customerMyBookings = '/customer/my-bookings';
  static const customerOrders = '/customer/orders';
  static const customerOrderDetail = '/customer/order-detail';
  static const customerMemberQr = '/customer/member-qr';
  static const customerProfile = '/customer/profile';
  static const customerSettings = '/customer/settings';
  static const customerHelp = '/customer/help';
  static const customerStoreLocation = '/customer/store-location';
  static const customerVouchers = '/customer/vouchers';
  static const customerFavorites = '/customer/favorites';

  // Order staff
  static const staffTables = '/order-staff/tables';
  static const staffTableDetail = '/order-staff/table-detail';
  static const staffCreateOrder = '/order-staff/create-order';
  static const staffTransferTable = '/order-staff/transfer-table';
  static const staffMergeTable = '/order-staff/merge-table';
  static const staffServingOrders = '/order-staff/serving-orders';
  static const staffProfile = '/order-staff/profile';
  static const staffSettings = '/order-staff/settings';

  // Cashier
  static const cashierDashboard = '/cashier/dashboard';
  static const cashierPendingPayment = '/cashier/pending-payment';
  static const cashierPayment = '/cashier/payment';
  static const cashierInvoice = '/cashier/invoice';
  static const cashierShift = '/cashier/shift';
  static const cashierHistory = '/cashier/history';
  static const cashierProfile = '/cashier/profile';
  static const cashierSettings = '/cashier/settings';
  static const cashierScanMember = '/cashier/scan-member';

  // Admin
  static const adminDashboard = '/admin/dashboard';
  static const adminAccounts = '/admin/accounts';
  static const adminMenu = '/admin/menu';
  static const adminTables = '/admin/tables';
  static const adminPromotions = '/admin/promotions';
  static const adminReports = '/admin/reports';

  /// Màn hình chính của từng vai trò sau khi đăng nhập.
  static String homeFor(UserRole role) => switch (role) {
        UserRole.customer => customerHome,
        UserRole.orderStaff => staffTables,
        UserRole.cashier => cashierDashboard,
        UserRole.admin => adminDashboard,
      };

  /// Sinh route cho toàn bộ ứng dụng dựa trên tên route + tham số truyền vào.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;

    Widget page;
    switch (settings.name) {
      // Auth
      case login:
        page = const LoginScreen();
        break;
      case register:
        page = const RegisterScreen();
        break;

      // Customer
      case customerHome:
        page = CustomerShell(initialTab: args is CustomerTab ? args : CustomerTab.home);
        break;
      case customerMenu:
        page = const MenuScreen();
        break;
      case customerFoodDetail:
        page = FoodDetailScreen(foodId: args as String);
        break;
      case customerBooking:
        page = const BookingTableScreen();
        break;
      // Luồng đặt bàn qua app: Đặt bàn -> Đặt món trước -> Thanh toán.
      case customerPreOrder:
        page = const PreOrderScreen();
        break;
      case customerBookingPayment:
        page = const BookingPaymentScreen();
        break;
      case customerBookingConfirmation:
        page = BookingConfirmationScreen(reservation: args as Reservation);
        break;
      case customerMyBookings:
        page = const MyBookingsScreen();
        break;
      case customerOrders:
        page = const OrderHistoryScreen();
        break;
      case customerOrderDetail:
        page = OrderDetailScreen(orderId: args as String);
        break;
      case customerMemberQr:
        page = const MemberQrScreen();
        break;
      case customerProfile:
        page = const CustomerProfileScreen();
        break;
      case customerSettings:
        page = const CustomerSettingsScreen();
        break;
      case customerHelp:
        page = const CustomerHelpScreen();
        break;
      case customerStoreLocation:
        page = const CustomerStoreLocationScreen();
        break;
      case customerVouchers:
        page = const VoucherWalletScreen();
        break;
      case customerFavorites:
        page = const FavoriteFoodsScreen();
        break;

      // Order staff
      case staffTables:
        page = const OrderStaffShell();
        break;
      case staffTableDetail:
        page = TableDetailScreen(tableId: args as String);
        break;
      case staffCreateOrder:
        page = CreateOrderScreen(tableId: args as String?);
        break;
      case staffTransferTable:
        page = TransferTableScreen(currentTableId: args as String);
        break;
      case staffMergeTable:
        page = MergeTableScreen(initialTableId: args as String);
        break;
      case staffServingOrders:
        page = const ServingOrdersScreen();
        break;
      case staffProfile:
        page = const StaffProfileScreen();
        break;
      case staffSettings:
        page = const StaffSettingsScreen();
        break;

      // Cashier
      case cashierDashboard:
        page = const CashierShell();
        break;
      case cashierPendingPayment:
        page = const PendingPaymentScreen();
        break;
      case cashierPayment:
        page = PaymentScreen(orderId: args as String);
        break;
      case cashierInvoice:
        page = InvoiceScreen(invoice: args as Invoice);
        break;
      case cashierShift:
        page = const ShiftScreen();
        break;
      case cashierHistory:
        page = const HistoryScreen();
        break;
      case cashierProfile:
        page = const CashierProfileScreen();
        break;
      case cashierScanMember:
        page = const ScanMemberScreen();
        break;
      case cashierSettings:
        page = const CashierSettingsScreen();
        break;

      // Admin
      case adminDashboard:
        page = const AdminShell();
        break;
      case adminAccounts:
        page = const AccountManagementScreen();
        break;
      case adminMenu:
        page = const MenuManagementScreen();
        break;
      case adminTables:
        page = const TableAreaManagementScreen();
        break;
      case adminPromotions:
        page = const PromotionManagementScreen();
        break;
      case adminReports:
        page = const RevenueReportScreen();
        break;

      default:
        page = const LoginScreen();
    }

    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
