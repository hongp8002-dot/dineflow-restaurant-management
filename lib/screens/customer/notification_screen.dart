import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/notification_repository.dart';
import '../../models/app_notification.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_animations.dart';
import '../../widgets/app_page_header.dart';
import '../../widgets/empty_state.dart';

/// Màn hình thông báo in-app của Khách hàng.
///
/// Hiển thị danh sách thông báo đặt bàn (đặt thành công, hủy bàn).
/// Mở từ tab Tài khoản → Thông báo.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _repo = NotificationRepository.instance;

  List<AppNotification>? _notifications;
  String? _error;
  bool _isLoading = true;
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _repo.fetchAll();
      if (mounted) setState(() => _notifications = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_isMarkingAll) return;
    setState(() => _isMarkingAll = true);
    try {
      await _repo.markAllRead();
      if (mounted) {
        // Cập nhật trạng thái local không cần gọi lại API
        setState(() {
          _notifications = _notifications
              ?.map((n) => AppNotification(
                    id: n.id,
                    type: n.type,
                    title: n.title,
                    body: n.body,
                    data: n.data,
                    isRead: true,
                    createdAt: n.createdAt,
                  ))
              .toList();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ));
      }
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _markOneRead(AppNotification n) async {
    if (n.isRead) return;
    try {
      await _repo.markRead(n.id);
      if (mounted) {
        setState(() {
          final idx = _notifications?.indexWhere((x) => x.id == n.id) ?? -1;
          if (idx >= 0 && _notifications != null) {
            _notifications![idx] = AppNotification(
              id: n.id,
              type: n.type,
              title: n.title,
              body: n.body,
              data: n.data,
              isRead: true,
              createdAt: n.createdAt,
            );
          }
        });
      }
    } catch (_) {
      // Lỗi đánh dấu đọc không nghiêm trọng → bỏ qua
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications?.any((n) => !n.isRead) ?? false;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: AppPageHeader(title: 'Thông báo')),
                  if (hasUnread)
                    TextButton(
                      onPressed: _isMarkingAll ? null : _markAllRead,
                      child: _isMarkingAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Đọc tất cả',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    final list = _notifications ?? [];
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Chưa có thông báo nào',
        message: 'Thông báo về lượt đặt bàn của bạn sẽ xuất hiện ở đây.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => FadeSlideIn.staggered(
          index: i,
          child: _NotificationTile(
            notification: list[i],
            onTap: () => _markOneRead(list[i]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final isConfirmed = n.type == 'reservation_confirmed';

    final iconColor = isConfirmed ? AppColors.success : AppColors.error;
    final iconBg = isConfirmed ? AppColors.successBg : AppColors.errorBg;
    final icon = isConfirmed
        ? Icons.event_available_rounded
        : Icons.event_busy_rounded;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.isRead ? AppColors.surface : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: n.isRead
              ? null
              : Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            // Nội dung
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight:
                                n.isRead ? FontWeight.w600 : FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, top: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppFormatters.relativeTime(n.createdAt),
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
