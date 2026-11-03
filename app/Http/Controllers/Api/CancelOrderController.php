<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Hủy đơn hàng (Thu ngân + Admin).
 *
 * Điều kiện: Đơn chưa thanh toán (payment_status = unpaid).
 * Sau hủy: status = cancelled, bàn được giải phóng (nếu có).
 * Không hoàn điểm (điểm chỉ cộng khi thanh toán thành công, đơn chưa TT chưa có điểm).
 */
class CancelOrderController extends ApiController
{
    /**
     * PATCH /api/orders/{order}/cancel
     */
    public function cancel(Request $request, Order $order): JsonResponse
    {
        // Chỉ hủy đơn chưa thanh toán
        if ($order->payment_status->value === 'paid') {
            return $this->fail(
                'Đơn đã thanh toán không thể hủy. Vui lòng liên hệ quản lý để hoàn tiền thủ công.',
                422
            );
        }

        // Đơn đã hủy rồi
        if ($order->status === OrderStatus::Cancelled) {
            return $this->fail('Đơn này đã được hủy trước đó.', 422);
        }

        // Đơn đã hoàn thành (completed) — không hủy được
        if ($order->status === OrderStatus::Completed) {
            return $this->fail('Đơn đã hoàn thành không thể hủy.', 422);
        }

        $order->update(['status' => OrderStatus::Cancelled]);

        // Giải phóng bàn nếu bàn đang serving chính đơn này
        if ($order->table_id) {
            $table = $order->table;
            if ($table && $table->current_order_id === $order->id) {
                $table->release();
            }
        }

        return $this->ok(
            OrderResource::make($order->fresh())->resolve(request()),
            "Đã hủy đơn #{$order->code}"
        );
    }
}
