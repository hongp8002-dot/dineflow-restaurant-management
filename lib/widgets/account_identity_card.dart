import 'package:flutter/material.dart';

import '../models/user.dart';
import '../theme/app_colors.dart';

/// Thẻ thông tin tài khoản ở đầu tab Cá nhân của nhân viên (Nhân viên Order,
/// Thu ngân): avatar tròn vàng, tên lớn, vai trò, số điện thoại.
class AccountIdentityCard extends StatelessWidget {
  final User user;

  const AccountIdentityCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Icon(Icons.person_outline_rounded, color: AppColors.textOnPrimary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    )),
                const SizedBox(height: 2),
                Text(user.role.label,
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                Text(user.phone, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
