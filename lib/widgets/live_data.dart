import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/mock_data.dart';

/// Bao quanh phần giao diện phụ thuộc dữ liệu động (bàn, đơn hàng).
///
/// - Tải mới các nhóm [sources] mỗi khi màn hình được mở (dữ liệu thay đổi liên tục).
/// - Dựng lại [builder] mỗi khi một trong các nhóm đó được cập nhật.
/// - Đưa hàm `refresh` cho [builder] để gắn vào `RefreshIndicator` (kéo để làm mới).
class LiveData extends StatefulWidget {
  final Set<LiveSource> sources;
  final Widget Function(BuildContext context, Future<void> Function() refresh) builder;

  const LiveData({super.key, required this.sources, required this.builder});

  @override
  State<LiveData> createState() => _LiveDataState();
}

class _LiveDataState extends State<LiveData> {
  late final Listenable _changes = Listenable.merge([
    for (final source in widget.sources)
      switch (source) {
        LiveSource.tables => MockData.tablesVersion,
        LiveSource.orders => MockData.ordersVersion,
        LiveSource.invoices => MockData.invoicesVersion,
        LiveSource.reservations => MockData.reservationsVersion,
        LiveSource.report => MockData.reportVersion,
      },
  ]);

  @override
  void initState() {
    super.initState();
    AppData.refresh(widget.sources); // âm thầm: lỗi mạng thì cứ dùng dữ liệu đang có
  }

  /// Kéo để làm mới: lỗi thì báo cho người dùng biết.
  Future<void> _refresh() async {
    final error = await AppData.refresh(widget.sources);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Không tải được $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _changes,
      builder: (context, _) => widget.builder(context, _refresh),
    );
  }
}
