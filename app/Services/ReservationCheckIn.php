<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Enums\ReservationStatus;
use App\Enums\TableStatus;
use App\Models\DiningTable;
use App\Models\Order;
use App\Models\Reservation;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Nhận bàn cho khách đã đặt trước (NV Order hoặc Thu ngân bấm khi khách tới quán).
 *
 * Trong một transaction:
 *  1. Kiểm tra lượt đặt còn "Sắp tới", đã xác nhận (không còn giữ bàn), và đang trong khung nhận bàn:
 *     từ EARLY_CHECKIN_MINUTES (30) phút trước đến GRACE_MINUTES (15) phút sau giờ hẹn.
 *     Trễ hơn nữa thì lượt đặt đã tự hủy (Reservation::expireNoShows).
 *  2. Khóa các bàn của lượt đặt; bàn phải còn hoạt động, không khóa, không có khách khác.
 *  3. Tạo đơn hàng gắn `reservation_id` (để khi thanh toán trừ tiền cọc) và khách hàng
 *     (để cộng điểm, giảm theo hạng); chép món đặt trước vào đơn với đúng giá lúc đặt.
 *  4. Mở MỌI bàn của lượt đặt và trỏ chúng tới cùng một đơn.
 *  5. Chuyển lượt đặt sang "Đã hoàn thành".
 */
class ReservationCheckIn
{
    /**
     * @throws ValidationException
     */
    public function handle(Reservation $reservation, User $staff): Order
    {
        // Ngoài transaction: nếu lượt đặt vừa bị hủy vì trễ quá 15 phút rồi bên dưới báo lỗi,
        // việc hủy (và thông báo cho khách) vẫn được lưu, không bị rollback theo.
        Reservation::expireStale();

        return DB::transaction(function () use ($reservation, $staff) {
            // Khóa dòng lượt đặt để hai nhân viên bấm cùng lúc không tạo hai đơn.
            $reservation = Reservation::lockForUpdate()->findOrFail($reservation->id);

            if ($reservation->status !== ReservationStatus::Upcoming) {
                $lateCancelled = $reservation->status === ReservationStatus::Cancelled
                    && now()->gt($reservation->checkInClosesAt());

                throw ValidationException::withMessages([
                    'reservation' => $lateCancelled
                        ? "Lượt đặt {$reservation->code} đã tự hủy vì khách trễ quá ".Reservation::GRACE_MINUTES.' phút. Hãy mở bàn như khách mới.'
                        : "Lượt đặt {$reservation->code} đang ở trạng thái \"{$reservation->status->getLabel()}\", không nhận bàn được.",
                ]);
            }

            if ($reservation->isHeld()) {
                throw ValidationException::withMessages([
                    'reservation' => 'Khách chưa hoàn tất đặt bàn (đang giữ chỗ), chưa nhận bàn được.',
                ]);
            }

            if (now()->lt($reservation->checkInOpensAt())) {
                throw ValidationException::withMessages([
                    'reservation' => 'Chưa tới giờ nhận bàn. Lượt đặt lúc '.$reservation->date_time->format('H:i')
                        .' nhận bàn được từ '.$reservation->checkInOpensAt()->format('H:i').'.',
                ]);
            }

            $tables = DiningTable::whereIn('id', $reservation->table_ids)->lockForUpdate()->get();

            if ($tables->count() !== count($reservation->table_ids)) {
                throw ValidationException::withMessages(['reservation' => 'Một số bàn của lượt đặt không còn tồn tại.']);
            }

            foreach ($tables as $table) {
                if (! $table->is_active || $table->is_locked) {
                    throw ValidationException::withMessages([
                        'reservation' => "{$table->number} đang tạm khóa hoặc ngừng phục vụ. Hãy mở khóa hoặc đổi bàn cho khách.",
                    ]);
                }
                if ($table->status === TableStatus::Serving) {
                    throw ValidationException::withMessages([
                        'reservation' => "{$table->number} vẫn đang có khách. Hãy thanh toán hoặc chuyển khách đang ngồi sang bàn khác rồi nhận bàn.",
                    ]);
                }
            }

            $order = Order::create([
                'table_id' => $tables->first()->id,
                'customer_id' => $reservation->customer_id,
                'staff_id' => $staff->id,
                'reservation_id' => $reservation->id,
                'status' => OrderStatus::Placed,
                'payment_status' => PaymentStatus::Unpaid,
                'note' => $reservation->note,
            ]);

            // Món đặt trước đã được dựng bằng LineItemBuilder lúc khách đặt (tên, giá, tùy chọn
            // lấy từ database). Giữ nguyên giá đó vì tiền cọc 50% đã tính trên giá này.
            $lines = collect($reservation->pre_order_items ?? [])->map(fn (array $line) => [
                'food_id' => $line['food_id'],
                'food_name' => $line['food_name'],
                'quantity' => $line['quantity'],
                'price' => $line['price'],
                'options' => $line['options'] ?? [],
                'note' => $line['note'] ?? null,
            ])->all();

            if ($lines) {
                $order->items()->createMany($lines);
            }
            $order->recalculateTotal();

            foreach ($tables as $table) {
                $table->occupy($order);
            }

            $reservation->update(['status' => ReservationStatus::Completed]);

            return $order;
        });
    }
}
