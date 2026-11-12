<?php

namespace App\Http\Controllers\Api;

use App\Enums\InvoiceStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethod;
use App\Http\Resources\InvoiceResource;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\Promotion;
use App\Models\Reservation;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CheckoutController extends ApiController
{
    /**
     * POST /api/orders/{order}/pay  (Thu ngân)
     *
     * Luồng thanh toán:
     * 1. Kiểm tra ca làm đang mở của thu ngân.
     * 2. Load order + items.
     * 3. Tính subtotal từ items.
     * 4. Áp dụng giảm giá promotion (nếu có).
     * 5. Trừ tiền cọc nếu đơn hàng có lượt đặt bàn đã thanh toán cọc.
     * 6. Tạo/cập nhật invoice, cộng điểm cho khách.
     * 7. Đổi trạng thái order → Completed.
     */
    public function pay(Request $request, Order $order): JsonResponse
    {
        // ── 1. Kiểm tra ca làm ──────────────────────────────────────────────
        $cashier = $request->user();
        $shift = Shift::where('cashier_id', $cashier->id)
            ->whereNull('ended_at')
            ->latest()
            ->first();

        if (! $shift) {
            return $this->fail('Bạn chưa mở ca làm. Vui lòng mở ca trước khi thanh toán.', 422);
        }

        // ── 2. Kiểm tra trạng thái order ────────────────────────────────────
        $order->load(['items.menuItem', 'customer', 'table', 'reservation']);

        if ($order->status === OrderStatus::Completed) {
            // Đơn đã thanh toán → trả về invoice hiện có
            $invoice = Invoice::where('order_id', $order->id)->first();
            if ($invoice) {
                return $this->ok(InvoiceResource::make($invoice->load(['order', 'cashier', 'promotion'])), 'Đơn hàng đã được thanh toán trước đó.');
            }
        }

        if (! in_array($order->status, [OrderStatus::Pending, OrderStatus::Processing, OrderStatus::ReadyToPay])) {
            return $this->fail('Đơn hàng không ở trạng thái có thể thanh toán.', 422);
        }

        // ── 3. Validate input ────────────────────────────────────────────────
        $data = $request->validate([
            'payment_method'   => ['required', Rule::enum(PaymentMethod::class)],
            'promotion_code'   => ['nullable', 'string'],
            'use_points'       => ['nullable', 'boolean'],
            'member_id'        => ['nullable', 'integer', 'exists:users,id'],
        ]);

        // ── 4. Tính subtotal ─────────────────────────────────────────────────
        $subtotal = $order->items->sum(function ($item) {
            $optionPrice = collect($item->options ?? [])->sum('price_modifier');

            return ((float) $item->price + $optionPrice) * $item->quantity;
        });

        // ── 5. Áp dụng promotion / voucher ──────────────────────────────────
        $discount     = 0.0;
        $promotionId  = null;
        $promotion    = null;

        if (! empty($data['promotion_code'])) {
            $promotion = Promotion::where('code', $data['promotion_code'])
                ->where('is_active', true)
                ->where(fn ($q) => $q->whereNull('expires_at')->orWhere('expires_at', '>', now()))
                ->first();

            if ($promotion) {
                $promotionId = $promotion->id;
                $discount = $this->calcPromoDiscount($promotion, $subtotal);
            }
        }

        // Điểm thành viên (nếu khách muốn dùng điểm)
        $pointsUsedDiscount = 0.0;
        $pointsUsed         = 0;
        $memberUser         = null;

        if (! empty($data['use_points']) && ! empty($data['member_id'])) {
            $memberUser = User::find($data['member_id']);
            if ($memberUser && $memberUser->loyalty_points > 0) {
                // 1 điểm = 1.000đ
                $maxPointsDiscount = $memberUser->loyalty_points * 1000;
                $pointsUsedDiscount = min($maxPointsDiscount, max(0.0, $subtotal - $discount));
                $pointsUsed = (int) ceil($pointsUsedDiscount / 1000);
            }
        }

        $discount += $pointsUsedDiscount;

        // ── 6. Trừ tiền cọc ─────────────────────────────────────────────────
        $depositAmount = 0.0;

        if ($order->reservation_id) {
            $reservation = $order->reservation
                ?? Reservation::find($order->reservation_id);

            if ($reservation && $reservation->isDepositPaid()) {
                $depositAmount = (float) $reservation->deposit_amount;
            }
        }

        // Tổng cần thanh toán = subtotal - giảm giá - cọc (không âm)
        $total = max(0.0, $subtotal - $discount - $depositAmount);

        // ── 7. Tạo / cập nhật Invoice ────────────────────────────────────────
        /** @var Invoice $invoice */
        $invoice = Invoice::updateOrCreate(
            ['order_id' => $order->id],
            [
                'cashier_id'     => $cashier->id,
                'shift_id'       => $shift->id,
                'promotion_id'   => $promotionId,
                'subtotal'       => $subtotal,
                'discount'       => $discount,
                'deposit_amount' => $depositAmount,   // ← ghi lại cọc đã trừ
                'total'          => $total,
                'payment_method' => $data['payment_method'],
                'status'         => InvoiceStatus::Paid,
                'paid_at'        => now(),
            ]
        );

        // ── 8. Cộng điểm thành viên (10.000đ = 1 điểm) ──────────────────────
        $pointsEarned = 0;
        $loyaltyUser  = $memberUser ?? $order->customer;

        if ($loyaltyUser) {
            $pointsEarned = (int) floor($total / 10000);

            if ($pointsEarned > 0) {
                $loyaltyUser->increment('loyalty_points', $pointsEarned);
            }

            // Trừ điểm đã dùng
            if ($pointsUsed > 0) {
                $loyaltyUser->decrement('loyalty_points', $pointsUsed);
            }
        }

        // ── 9. Hoàn tất order ────────────────────────────────────────────────
        $order->update([
            'status'         => OrderStatus::Completed,
            'payment_status' => 'paid',
        ]);

        return $this->ok(
            InvoiceResource::make($invoice->load(['order.table', 'cashier', 'promotion']))->additional([
                'points_earned' => $pointsEarned,
            ]),
            'Thanh toán thành công.',
            200,
        );
    }

    /**
     * GET /api/orders/{order}/invoice  (Thu ngân / Admin)
     */
    public function show(Order $order): JsonResponse
    {
        $invoice = Invoice::where('order_id', $order->id)
            ->with(['order.table', 'order.items.menuItem', 'cashier', 'promotion'])
            ->first();

        if (! $invoice) {
            return $this->fail('Chưa có hóa đơn cho đơn hàng này.', 404);
        }

        return $this->ok(InvoiceResource::make($invoice));
    }

    /* ── Private helpers ──────────────────────────────────────────────────── */

    private function calcPromoDiscount(Promotion $promo, float $subtotal): float
    {
        if ($promo->type === 'percent') {
            $d = $subtotal * ($promo->value / 100);

            return $promo->max_discount ? min($d, $promo->max_discount) : $d;
        }

        // type === 'fixed'
        return min((float) $promo->value, $subtotal);
    }
}
