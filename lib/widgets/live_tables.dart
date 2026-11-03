import 'package:flutter/material.dart';

import '../data/app_data.dart';
import 'live_data.dart';

/// [LiveData] chỉ theo dõi danh sách bàn (dùng cho các màn chỉ cần bàn).
class LiveTables extends StatelessWidget {
  final Widget Function(BuildContext context, Future<void> Function() refresh) builder;

  const LiveTables({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => LiveData(sources: const {LiveSource.tables}, builder: builder);
}
