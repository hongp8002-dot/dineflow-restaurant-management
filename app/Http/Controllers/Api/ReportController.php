<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class ReportController extends ApiController
{
    /** Số ngày tính món bán chạy. */
    private const TOP_FOODS_DAYS = 30;

    private const TOP_FOODS_LIMIT = 10;

    /** Khoảng ngày tùy chỉnh tối đa (để biểu đồ cột còn đọc được). */
    private const MAX_RANGE_DAYS = 31;

    /**
     * GET /api/reports/overview  (admin)
     * Số liệu cho Dashboard và Báo cáo doanh thu: doanh thu = tổng hóa đơn đã thanh toán, theo giờ của hệ thống.
     */
    public function overview(): JsonResponse
    {
        $now = now();
        $today = $now->copy()->startOfDay();
        $thisWeek = $now->copy()->startOfWeek(); // thứ Hai
        $firstMonth = $now->copy()->startOfMonth()->subMonths(5);
        $firstWeek = $thisWeek->copy()->subWeeks(5);
        $firstDay = $today->copy()->subDays(6);

        // Mọi mốc cần thống kê nằm trong 6 tháng gần nhất (6 tháng luôn dài hơn 6 tuần và 7 ngày).
        $invoices = Invoice::paid()
            ->where('paid_at', '>=', $firstMonth)
            ->get(['paid_at', 'total']);

        $sum = fn (Carbon $from, ?Carbon $to = null): float => (float) $invoices
            ->filter(fn (Invoice $i) => $i->paid_at >= $from && ($to === null || $i->paid_at < $to))
            ->sum('total');

        $todayOrders = Order::where('created_at', '>=', $today)
            ->where('status', '!=', OrderStatus::Cancelled);

        return $this->ok([
            'today_revenue' => $sum($today),
            'yesterday_revenue' => $sum($today->copy()->subDay(), $today),
            'week_revenue' => $sum($thisWeek),
            'last_week_revenue' => $sum($thisWeek->copy()->subWeek(), $thisWeek),
            'today_orders' => (clone $todayOrders)->count(),
            // Chỉ đếm được khách có tài khoản; đơn gọi tại bàn không gắn khách.
            'today_members' => (clone $todayOrders)->whereNotNull('customer_id')->distinct()->count('customer_id'),

            'revenue_by_day' => $this->series(6, $firstDay, fn (Carbon $d) => $d->copy()->addDay(), fn (Carbon $d) => $this->weekdayLabel($d), $sum),
            'revenue_by_week' => $this->series(5, $firstWeek, fn (Carbon $d) => $d->copy()->addWeek(), fn (Carbon $d) => $d->format('d/m'), $sum),
            'revenue_by_month' => $this->series(5, $firstMonth, fn (Carbon $d) => $d->copy()->addMonth(), fn (Carbon $d) => 'T' . $d->month, $sum),

            'top_foods_days' => self::TOP_FOODS_DAYS,
            'top_foods' => $this->topFoods($today->copy()->subDays(self::TOP_FOODS_DAYS - 1)),
        ]);
    }

    /**
     * GET /api/reports/revenue?from=2026-10-01&to=2026-10-15  (admin)
     * Doanh thu từng ngày trong khoảng ngày tùy chỉnh (tính cả hai đầu, tối đa 31 ngày, không quá hôm nay).
     */
    public function revenue(Request $request): JsonResponse
    {
        $data = $request->validate([
            'from' => ['required', 'date_format:Y-m-d'],
            'to' => ['required', 'date_format:Y-m-d', 'after_or_equal:from', 'before_or_equal:today'],
        ], [
            'to.after_or_equal' => 'Ngày kết thúc phải sau hoặc bằng ngày bắt đầu.',
            'to.before_or_equal' => 'Không chọn được ngày trong tương lai.',
        ]);

        $from = Carbon::createFromFormat('Y-m-d', $data['from'])->startOfDay();
        $to = Carbon::createFromFormat('Y-m-d', $data['to'])->startOfDay();
        $days = (int) $from->diffInDays($to) + 1;

        if ($days > self::MAX_RANGE_DAYS) {
            return $this->fail('Chỉ xem được tối đa ' . self::MAX_RANGE_DAYS . ' ngày mỗi lần.', 422);
        }

        $invoices = Invoice::paid()
            ->where('paid_at', '>=', $from)
            ->where('paid_at', '<', $to->copy()->addDay())
            ->get(['paid_at', 'total']);

        $sum = fn (Carbon $start, ?Carbon $end = null): float => (float) $invoices
            ->filter(fn (Invoice $i) => $i->paid_at >= $start && ($end === null || $i->paid_at < $end))
            ->sum('total');

        $points = $this->series($days - 1, $from, fn (Carbon $d) => $d->copy()->addDay(), fn (Carbon $d) => $d->format('d/m'), $sum);

        return $this->ok([
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'total' => (float) $invoices->sum('total'),
            'revenue_by_day' => $points,
        ]);
    }

    /**
     * Chuỗi doanh thu $count + 1 mốc liên tiếp, bắt đầu từ $first, cũ nhất trước.
     *
     * @return array<int, array{label: string, amount: float}>
     */
    private function series(int $count, Carbon $first, callable $next, callable $label, callable $sum): array
    {
        $points = [];
        $from = $first->copy();
        for ($i = 0; $i <= $count; $i++) {
            $to = $next($from);
            $points[] = ['label' => $label($from), 'amount' => $sum($from, $to)];
            $from = $to;
        }

        return $points;
    }

    private function weekdayLabel(Carbon $day): string
    {
        return $day->dayOfWeekIso === 7 ? 'CN' : 'T' . ($day->dayOfWeekIso + 1);
    }

    /**
     * Món bán chạy (theo số lượng) trong các đơn đã thanh toán từ $since. Doanh thu món chưa trừ khuyến mãi.
     *
     * @return array<int, array{food_name: string, sold_quantity: int, revenue: float}>
     */
    private function topFoods(Carbon $since): array
    {
        /** @var Collection<int, OrderItem> $items */
        $items = OrderItem::whereHas('order.invoice', fn ($q) => $q->paid()->where('paid_at', '>=', $since))->get();

        return $items
            ->groupBy('food_name')
            ->map(fn (Collection $rows, string $name) => [
                'food_name' => $name,
                'sold_quantity' => (int) $rows->sum('quantity'),
                'revenue' => (float) $rows->sum(fn (OrderItem $item) => $item->line_total),
            ])
            ->sortByDesc('sold_quantity')
            ->take(self::TOP_FOODS_LIMIT)
            ->values()
            ->all();
    }
}
