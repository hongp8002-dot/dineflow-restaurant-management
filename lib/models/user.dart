/// Vai trò người dùng trong hệ thống.
enum UserRole { admin, orderStaff, cashier, customer }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.orderStaff:
        return 'Nhân viên Order';
      case UserRole.cashier:
        return 'Thu ngân';
      case UserRole.customer:
        return 'Khách hàng';
    }
  }
}

enum AccountStatus { active, locked }

/// Tài khoản người dùng (dùng cho Admin quản lý & mock đăng nhập).
class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final AccountStatus status;
  final String? avatarUrl;

  /// Mã thành viên và điểm tích lũy (chỉ có ý nghĩa với Khách hàng).
  final String? memberCode;
  final int points;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.status = AccountStatus.active,
    this.avatarUrl,
    this.memberCode,
    this.points = 0,
  });

  /// Đọc `user` do API trả về (khóa `snake_case`, id là số nên đổi sang chuỗi).
  factory User.fromApiJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: switch (json['role']) {
        'admin' => UserRole.admin,
        'order_staff' => UserRole.orderStaff,
        'cashier' => UserRole.cashier,
        _ => UserRole.customer,
      },
      status: json['status'] == 'locked' ? AccountStatus.locked : AccountStatus.active,
      avatarUrl: json['avatar_url'] as String?,
      memberCode: json['member_code'] as String?,
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}
