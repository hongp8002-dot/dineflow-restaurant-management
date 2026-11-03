<?php

namespace App\Http\Controllers\Api;

use App\Enums\InvoiceStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Enums\ShiftStatus;
use App\Http\Resources\InvoiceResource;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\Promotion;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class CheckoutController extends ApiController
{
    /**
     * POST /api/orders/{id}/pay
     * body: { "payment_method": "cash|qr|card", "promotion_code": "WELCOME10" }
     *
     * Quy tắc Kiểu A:
     * - Không dùng điểm để trừ tiền.
     * - Giảm theo hạng: Silver 0%, Gold ≥500đ giảm 5%, Platinum ≥1500đ giảm 10%.
     * - Giảm = max(giảm theo hạng, giảm theo voucher). Không cộng dồn.
     * - Cộng điểm: floor(total_thực_trả / 10000) × 2.
     * - Thu ngân phải có ca đang mở mới thanh toán được.
     */
    public function pay(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'payment_method' => ['required', Rule::enum(PaymentMethod::class)],
            'promotion_code' => ['nullable', 'string', 'max:30'],
        ]);

        $invoice = DB::transaction(function () use ($request, $data, $order) {
            // ── 1. Kiểm tra ca đang mở ──────────────────────────────────
            $shift = Shift::open()
                ->where('cashier_id', $request->user()->id)
                ->lockForUpdate()
                ->first();

            if (! $shift) {
                throw ValidationException::withMessages([
                    'shift' => 'Bạn chưa mở ca làm việc. Vui lòng mở ca trước khi thanh toán.',
                ]);
            }

            // ── 2. Kiểm tra đơn ─────────────────────────────────────────
            $order = Order::lockForUpdate()->findOrFail($order->id);

            if ($order->isPaid()) {
                throw ValidationException::withMessages(['order' => 'Đơn này đã được thanh toán.']);
            }
            if ($order->status === OrderStatus::Cancelled) {
                throw ValidationException::withMessages(['order' => 'Đơn đã hủy, không thể thanh toán.']);
            }
            if ($order->items()->doesntExist()) {
                throw ValidationException::withMessages(['order' => 'Đơn chưa có món nào.']);
            }

            $subtotal = (float) $order->total_amount;

            // ── 3. Giảm theo voucher ─────────────────────────────────────
            $promotion     = null;
            $promoDiscount = 0.0;

            if (filled($data['promotion_code'] ?? null)) {
                $promotion = Promotion::where('code', strtoupper(trim($data['promotion_code'])))->first();

                if (! $promotion) {
                    throw ValidationException::withMessages(['promotion_code' => 'Mã khuyến mãi không tồn tại.']);
                }
                if (! $promotion->isApplicableTo($subtotal)) {
                    $min = number_format((float) $promotion->min_order_amount, 0, ',', '.');
                    throw ValidationException::withMessages([
                        'promotion_code' => "Mã {$promotion->code} đã hết hạn, chưa bắt đầu hoặc đơn chưa đạt tối thiểu {$min}đ.",
                    ]);
                }

                $promoDiscount = $promotion->calculateDiscount($subtotal);
            }

            // ── 4. Giảm theo hạng thành viên (Kiểu A) ───────────────────
            $tierDiscount    = 0.0;
            $customer        = $order->customer_id ? User::lockForUpdate()->find($order->customer_id) : null;

            if ($customer) {
                $tierPercent  = match (true) {
                    $customer->points >= 1500 => 10, // Platinum
                    $customer->points >= 500  => 5,  // Gold
                    default                   => 0,  // Silver
                };
                $tierDiscount = round($subtotal * $tierPercent / 100, 2);
            }

            // Lấy mức giảm CAO HƠN giữa hạng và voucher (không cộng dồn).
            // Nếu dùng voucher mà hạng giảm nhiều hơn → hạng thắng, promotion_id không ghi vào.
            $discount = max($promoDiscount, $tierDiscount);
            if ($discount === $tierDiscount && $tierDiscount > $promoDiscount) {
                // Hạng thắng: không ghi promotion vào hóa đơn
                $promotion = null;
            }

            $total = max(0.0, $subtotal - $discount);

            // ── 5. Tạo hóa đơn ──────────────────────────────────────────
            $invoice = Invoice::updateOrCreate(['order_id' => $order->id], [
                'cashier_id'   => $request->user()->id,
                'shift_id'     => $shift->id,
                'promotion_id' => $promotion?->id,
                'subtotal'     => $subtotal,
                'discount'     => $discount,
                'total'        => $total,
                'payment_method' => $data['payment_method'],
                'status'       => InvoiceStatus::Paid,
                'paid_at'      => now(),
            ]);

            // ── 6. Đóng đơn và trả bàn ──────────────────────────────────
            $order->update([
                'payment_status' => PaymentStatus::Paid,
                'status'         => OrderStatus::Completed,
            ]);
            $order->releaseTableIfDone();

            // ── 7. Cộng điểm cho khách (Kiểu A: floor(total / 10000) × 2) ─
            if ($customer && $total > 0) {
                $pointsEarned = (int) floor($total / 10000) * 2;
                if ($pointsEarned > 0) {
                    $customer->increment('points', $pointsEarned);
                }
            }

            return $invoice;
        });

        return $this->ok(
            InvoiceResource::make($invoice->load(['order.table', 'order.items', 'cashier', 'promotion'])),
            'Thanh toán thành công.',
        );
    }
}
