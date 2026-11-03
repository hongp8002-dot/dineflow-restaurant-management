/// Doanh thu theo một mốc thời gian (một cột của biểu đồ).
class RevenuePoint {
  final String label;
  final double amount;

  const RevenuePoint({required this.label, required this.amount});

  factory RevenuePoint.fromApiJson(Map<String, dynamic> json) => RevenuePoint(
        label: json['label'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}

/// Món bán chạy trong báo cáo.
class TopFoodStat {
  final String foodName;
  final int soldQuantity;
  final double revenue;

  const TopFoodStat({
    required this.foodName,
    required this.soldQuantity,
    required this.revenue,
  });

  factory TopFoodStat.fromApiJson(Map<String, dynamic> json) => TopFoodStat(
        foodName: json['food_name'] as String,
        soldQuantity: (json['sold_quantity'] as num).toInt(),
        revenue: (json['revenue'] as num).toDouble(),
      );
}

/// Số liệu báo cáo của Admin (Dashboard + Báo cáo doanh thu), do server tính từ hóa đơn đã thanh toán.
class ReportOverview {
  final double todayRevenue;
  final double yesterdayRevenue;
  final double weekRevenue;
  final double lastWeekRevenue;
  final int todayOrders;

  /// Số khách có tài khoản đã đặt hôm nay (đơn gọi tại bàn không gắn khách nên không đếm được).
  final int todayMembers;

  final List<RevenuePoint> revenueByDay;
  final List<RevenuePoint> revenueByWeek;
  final List<RevenuePoint> revenueByMonth;

  /// Món bán chạy trong [topFoodsDays] ngày gần nhất, bán nhiều nhất trước.
  final int topFoodsDays;
  final List<TopFoodStat> topFoods;

  const ReportOverview({
    this.todayRevenue = 0,
    this.yesterdayRevenue = 0,
    this.weekRevenue = 0,
    this.lastWeekRevenue = 0,
    this.todayOrders = 0,
    this.todayMembers = 0,
    this.revenueByDay = const [],
    this.revenueByWeek = const [],
    this.revenueByMonth = const [],
    this.topFoodsDays = 30,
    this.topFoods = const [],
  });

  /// Trước khi tải xong (hoặc tải lỗi): toàn số 0, danh sách rỗng.
  static const empty = ReportOverview();

  factory ReportOverview.fromApiJson(Map<String, dynamic> json) {
    List<RevenuePoint> points(String key) => [
          for (final p in (json[key] as List<dynamic>).cast<Map<String, dynamic>>())
            RevenuePoint.fromApiJson(p),
        ];

    return ReportOverview(
      todayRevenue: (json['today_revenue'] as num).toDouble(),
      yesterdayRevenue: (json['yesterday_revenue'] as num).toDouble(),
      weekRevenue: (json['week_revenue'] as num).toDouble(),
      lastWeekRevenue: (json['last_week_revenue'] as num).toDouble(),
      todayOrders: (json['today_orders'] as num).toInt(),
      todayMembers: (json['today_members'] as num).toInt(),
      revenueByDay: points('revenue_by_day'),
      revenueByWeek: points('revenue_by_week'),
      revenueByMonth: points('revenue_by_month'),
      topFoodsDays: (json['top_foods_days'] as num).toInt(),
      topFoods: [
        for (final f in (json['top_foods'] as List<dynamic>).cast<Map<String, dynamic>>())
          TopFoodStat.fromApiJson(f),
      ],
    );
  }

  /// Phần trăm thay đổi so với kỳ trước, làm tròn; null nếu kỳ trước không có doanh thu (không chia được).
  static int? changePercent(double current, double previous) =>
      previous <= 0 ? null : ((current - previous) / previous * 100).round();
}
