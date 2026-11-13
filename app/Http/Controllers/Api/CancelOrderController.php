<?php

namespace App\Http\Controllers\Api;

use App\Enums\CancelReason;
use App\Enums\OrderStatus;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

/**
 * Hủy đơn hàng (Thu ngân + Admin) — bắt buộc lý do (nhóm chốt 13/11, cách A).
 *
 * Điều kiện và việc lưu lý do / người hủy / thời điểm nằm ở Order::cancelBy(),
 * dùng chung với nút Hủy đơn trên web /admin.
 * Không hoàn điểm (điểm chỉ cộng khi thanh toán thành công, đơn chưa TT chưa có điểm).
 */
class CancelOrderController extends ApiController
{
    private const RELATIONS = ['table', 'customer', 'staff', 'items', 'reservation', 'cancelledBy'];

    /**
     * PATCH /api/orders/{order}/cancel
     * body: { "reason": "wrong_entry|customer_left|out_of_stock|other", "note": "..." (bắt buộc khi other) }
     */
    public function cancel(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'reason' => ['required', Rule::enum(CancelReason::class)],
            'note' => ['nullable', 'string', 'max:255', 'required_if:reason,other'],
        ], [
            'reason.required' => 'Vui lòng chọn lý do hủy đơn.',
            'reason.enum' => 'Lý do hủy không hợp lệ.',
            'note.required_if' => 'Chọn lý do "Khác" thì phải ghi rõ lý do.',
            'note.max' => 'Ghi chú tối đa 255 ký tự.',
        ]);

        $order->cancelBy($request->user(), CancelReason::from($data['reason']), $data['note'] ?? null);

        return $this->ok(
            OrderResource::make($order->fresh(self::RELATIONS))->resolve(request()),
            "Đã hủy đơn #{$order->code}"
        );
    }

    /**
     * GET /api/admin/cancelled-orders?date=2026-11-13  (Admin)
     * Các đơn bị hủy trong một ngày (giờ của quán, mặc định hôm nay), mới nhất trước,
     * kèm lý do, ghi chú, người hủy.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate(['date' => ['nullable', 'date_format:Y-m-d']]);

        $tz = config('restaurant.timezone');
        $start = $request->filled('date')
            ? Carbon::createFromFormat('!Y-m-d', $request->input('date'), $tz)
            : now($tz)->startOfDay();
        $dbTz = config('app.timezone');

        $orders = Order::with(self::RELATIONS)
            ->where('status', OrderStatus::Cancelled)
            ->where('cancelled_at', '>=', $start->copy()->setTimezone($dbTz))
            ->where('cancelled_at', '<', $start->copy()->addDay()->setTimezone($dbTz))
            ->orderByDesc('cancelled_at')
            ->get();

        return $this->ok([
            'date' => $start->toDateString(),
            'total_amount' => (float) $orders->sum('total_amount'),
            'orders' => $this->items($orders, OrderResource::class),
        ]);
    }
}
