<?php

namespace App\Http\Controllers\Api;

use App\Enums\InvoiceStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Enums\ShiftStatus;
use App\Enums\UserRole;
use App\Enums\UserStatus;
use App\Http\Resources\InvoiceResource;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\Promotion;
use App\Models\Reservation;
use App\Models\Shift;
use App\Models\User;
use App\Services\LoyaltyRules;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class CheckoutController extends ApiController
{
    /**
     * POST /api/orders/{id}/pay
     * body: { "payment_method": "cash|qr|card", "promotion_code": "WELCOME10", "member_code": "DF-MB0001" }
     *
     * member_code: mã thành viên thu ngân quét QR / nhập tay. Đơn chưa gắn khách (vd đơn tại bàn do
     * NV Order tạo) thì gắn khách này vào đơn để giảm theo hạng và cộng điểm. Đơn đã gắn khách
     * khác (đơn khách tự đặt / nhận bàn đặt trước) thì từ chối, không đổi chủ đơn.
     *
     * Quy tắc Kiểu A:
     * - Không dùng điểm để trừ tiền.
     * - Giảm theo hạng: theo hạng thành viên (ngưỡng điểm và % trong config/loyalty.php).
     * - Giảm = max(giảm theo hạng, giảm theo voucher). Không cộng dồn.
     * - Cộng điểm: theo số tiền thực trả (config/loyalty.php).
     * - Thu ngân phải có ca đang mở mới thanh toán được.
     * - Tiền cọc (nếu đơn gắn đặt bàn có đặt món trước) được khấu trừ SAU khi tính giảm giá.
     */
    public function pay(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate([
            'payment_method' => ['required', Rule::enum(PaymentMethod::class)],
            'promotion_code' => ['nullable', 'string', 'max:30'],
            'member_code' => ['nullable', 'string', 'max:30'],
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

            // Thu ngân quét / nhập mã thành viên → gắn khách vào đơn (cùng điều kiện với GET /members/{code})
            if (filled($data['member_code'] ?? null)) {
                $member = User::where('member_code', strtoupper(trim($data['member_code'])))
                    ->where('role', UserRole::Customer)
                    ->where('status', UserStatus::Active)
                    ->lockForUpdate()
                    ->first();

                if (! $member) {
                    throw ValidationException::withMessages(['member_code' => 'Không tìm thấy thành viên có mã "'.$data['member_code'].'".']);
                }
                if ($customer && $customer->id !== $member->id) {
                    throw ValidationException::withMessages([
                        'member_code' => "Đơn này đã gắn với khách {$customer->name}, không đổi sang thành viên khác.",
                    ]);
                }
                if (! $customer) {
                    $order->update(['customer_id' => $member->id]);
                    $customer = $member;
                }
            }

            if ($customer) {
                $tierPercent  = LoyaltyRules::discountPercentFor((int) $customer->points); // config/loyalty.php
                $tierDiscount = round($subtotal * $tierPercent / 100, 2);
            }

            // Lấy mức giảm CAO HƠN giữa hạng và voucher (không cộng dồn).
            // Nếu dùng voucher mà hạng giảm nhiều hơn → hạng thắng, promotion_id không ghi vào.
            $discount = max($promoDiscount, $tierDiscount);
            if ($discount === $tierDiscount && $tierDiscount > $promoDiscount) {
                // Hạng thắng: không ghi promotion vào hóa đơn
                $promotion = null;
            }

            // ── 5. Khấu trừ tiền cọc (nếu đơn gắn đặt bàn có cọc) ──────
            // Tiền cọc được trừ SAU khi tính giảm giá (subtotal - discount - deposit).
            $depositAmount = 0.0;
            if ($order->reservation_id) {
                $reservation = Reservation::find($order->reservation_id);
                if ($reservation && $reservation->isDepositPaid()) {
                    $depositAmount = (float) $reservation->deposit_amount;
                }
            }

            $total = max(0.0, $subtotal - $discount - $depositAmount);

            // ── 6. Tạo hóa đơn ──────────────────────────────────────────
            $invoice = Invoice::updateOrCreate(['order_id' => $order->id], [
                'cashier_id'     => $request->user()->id,
                'shift_id'       => $shift->id,
                'promotion_id'   => $promotion?->id,
                'subtotal'       => $subtotal,
                'discount'       => $discount,
                'deposit_amount' => $depositAmount,
                'total'          => $total,
                'payment_method' => $data['payment_method'],
                'status'         => InvoiceStatus::Paid,
                'paid_at'        => now(),
            ]);

            // ── 7. Đóng đơn và trả bàn ──────────────────────────────────
            $order->update([
                'payment_status' => PaymentStatus::Paid,
                'status'         => OrderStatus::Completed,
            ]);
            $order->releaseTableIfDone();

            // ── 8. Cộng điểm cho khách (Kiểu A, config/loyalty.php) ─
            if ($customer && $total > 0) {
                $pointsEarned = LoyaltyRules::pointsEarned($total);
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
