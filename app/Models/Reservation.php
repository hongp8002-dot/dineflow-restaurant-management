<?php

namespace App\Models;

use App\Enums\PaymentMethod;
use App\Enums\ReservationStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Carbon;

class Reservation extends Model
{
    /**
     * Một bàn đã có lượt đặt thì không nhận lượt khác trong ±90 phút quanh giờ đó.
     * Cũng là khoảng "sắp tới" để chặn bàn đang có khách ngồi (xem DiningTable::isBookableAt).
     * Dùng chung cho kiểm tra bàn trống (TableController) và đặt bàn (ReservationController).
     */
    public const WINDOW_MINUTES = 90;

    /** Khách trễ quá số phút này so với giờ hẹn thì lượt đặt tự hủy (coi như không đến), mất cọc. */
    public const GRACE_MINUTES = 15;

    /** Nhận bàn sớm tối đa số phút này trước giờ hẹn (nếu bàn trống). */
    public const EARLY_CHECKIN_MINUTES = 30;

    protected $fillable = [
        'code',
        'customer_id',
        'table_ids',
        'area',
        'date_time',
        'guest_count',
        'note',
        'status',
        'hold_expires_at',
        'pre_order_items',
        'pre_order_payment',
        'deposit_amount',
        'deposit_paid_at',
    ];

    protected function casts(): array
    {
        return [
            'table_ids' => 'array',
            'pre_order_items' => 'array',
            'date_time' => 'datetime',
            'hold_expires_at' => 'datetime',
            'deposit_paid_at' => 'datetime',
            'guest_count' => 'integer',
            'deposit_amount' => 'decimal:2',
            'status' => ReservationStatus::class,
            'pre_order_payment' => PaymentMethod::class,
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Reservation $reservation) {
            $reservation->code ??= static::generateCode();
        });
    }

    /** Sinh mã dạng DF-8921, đảm bảo không trùng. */
    public static function generateCode(): string
    {
        do {
            $code = 'DF-' . random_int(1000, 9999);
        } while (static::where('code', $code)->exists());

        return $code;
    }

    /* ---------------- Relationships ---------------- */

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    /** Đơn hàng được tạo khi khách đến nhận bàn. */
    public function order(): HasOne
    {
        return $this->hasOne(Order::class);
    }

    /**
     * Các bàn được ghép trong lượt đặt (table_ids là JSON nên không dùng relationship chuẩn).
     *
     * @return Collection<int, DiningTable>
     */
    public function tables(): Collection
    {
        $ids = $this->table_ids ?? [];

        return DiningTable::whereIn('id', $ids)->get()
            ->sortBy(fn (DiningTable $t) => array_search($t->id, $ids))
            ->values();
    }

    /* ---------------- Helpers ---------------- */

    /** Tổng tiền món đặt trước (đơn giá + options) * số lượng. */
    public function preOrderTotal(): float
    {
        return collect($this->pre_order_items ?? [])->sum(function (array $item) {
            $extra = collect($item['options'] ?? [])->sum('price_modifier');

            return ((float) $item['price'] + $extra) * (int) $item['quantity'];
        });
    }

    /**
     * Tính tiền cọc = 50% tổng món đặt trước, làm tròn lên 100đ.
     * Trả về 0 nếu không có món đặt trước.
     */
    public function calculateDeposit(): float
    {
        $total = $this->preOrderTotal();
        if ($total <= 0) {
            return 0.0;
        }

        return (float) (ceil(($total * 0.5) / 100) * 100);
    }

    /** Khách đã thanh toán cọc hay chưa (deposit_paid_at != null). */
    public function isDepositPaid(): bool
    {
        return $this->deposit_paid_at !== null;
    }

    /** Đang giữ bàn chờ khách xác nhận (chưa xác nhận thì còn hạn giữ). */
    public function isHeld(): bool
    {
        return $this->hold_expires_at !== null;
    }

    /**
     * Hủy các lượt giữ bàn đã quá hạn mà khách không xác nhận (vd. khách tắt app giữa chừng),
     * để bàn không bị chặn vô ích. Gọi trước các thao tác đọc/kiểm tra xung đột.
     */
    public static function expireLapsedHolds(): void
    {
        static::where('status', ReservationStatus::Upcoming)
            ->whereNotNull('hold_expires_at')
            ->where('hold_expires_at', '<=', now())
            ->update(['status' => ReservationStatus::Cancelled]);
    }

    /**
     * Hủy các lượt đặt đã xác nhận mà khách trễ quá GRACE_MINUTES phút (không đến),
     * để bàn được nhả cho khách khác. Tiền cọc giữ nguyên trong DB (không hoàn).
     * Gửi thông báo cho từng khách bị hủy.
     *
     * Cập nhật từng dòng kèm điều kiện status = upcoming: nếu hai request chạy cùng lúc,
     * chỉ request nào đổi được dòng đó mới gửi thông báo → không gửi trùng.
     */
    public static function expireNoShows(): void
    {
        $lapsed = static::where('status', ReservationStatus::Upcoming)
            ->whereNull('hold_expires_at')
            ->where('date_time', '<', now()->subMinutes(self::GRACE_MINUTES))
            ->get();

        foreach ($lapsed as $reservation) {
            $changed = static::whereKey($reservation->id)
                ->where('status', ReservationStatus::Upcoming)
                ->update(['status' => ReservationStatus::Cancelled]);

            if ($changed) {
                AppNotification::reservationNoShow($reservation);
            }
        }
    }

    /**
     * Hủy lượt đặt đang "Sắp tới" và báo cho khách. Tiền cọc KHÔNG hoàn: deposit_amount và
     * deposit_paid_at giữ nguyên làm bằng chứng đối soát. Bàn không cần trả lại vì trạng thái
     * "đã đặt" của bàn tính từ các lượt còn "Sắp tới".
     * Dùng chung cho API (khách / nhân viên trên app) và nút Hủy trên web /admin.
     */
    public function cancelAndNotify(): void
    {
        $this->update(['status' => ReservationStatus::Cancelled, 'hold_expires_at' => null]);

        AppNotification::reservationCancelled(
            $this->customer_id,
            $this->id,
            $this->date_time->format('H:i d/m/Y'),
        );
    }

    /**
     * Dọn mọi lượt đặt không còn hiệu lực trước khi đọc hoặc kiểm tra xung đột:
     * lượt giữ bàn quá hạn và lượt khách đến trễ quá GRACE_MINUTES phút.
     */
    public static function expireStale(): void
    {
        static::expireLapsedHolds();
        static::expireNoShows();
    }

    /** Thời điểm sớm nhất được nhận bàn. */
    public function checkInOpensAt(): \Illuminate\Support\Carbon
    {
        return $this->date_time->copy()->subMinutes(self::EARLY_CHECKIN_MINUTES);
    }

    /** Thời điểm muộn nhất được nhận bàn (sau đó lượt đặt tự hủy). */
    public function checkInClosesAt(): \Illuminate\Support\Carbon
    {
        return $this->date_time->copy()->addMinutes(self::GRACE_MINUTES);
    }

    /* ---------------- Scopes ---------------- */

    /**
     * Lượt đặt có giờ đến nằm trong NGÀY $date (Y-m-d) theo giờ của quán (config restaurant.timezone).
     * Database lưu UTC nên không dùng whereDate: 02:00 sáng 14/11 giờ VN = 19:00 ngày 13/11 UTC.
     * Dùng chung cho API GET /reservations (app) và trang Lịch đặt bàn trên web /admin.
     */
    public function scopeOnRestaurantDate(Builder $query, string $date): Builder
    {
        $start = Carbon::parse($date, config('restaurant.timezone'))->startOfDay()->setTimezone(config('app.timezone'));

        return $query->where('date_time', '>=', $start)->where('date_time', '<', $start->copy()->addDay());
    }

    public function scopeUpcoming(Builder $query): Builder
    {
        return $query->where('status', ReservationStatus::Upcoming);
    }

    /** Lượt đặt đang chiếm bàn: sắp tới và (đã xác nhận hoặc còn hạn giữ). */
    public function scopeBlocking(Builder $query): Builder
    {
        return $query->where('status', ReservationStatus::Upcoming)
            ->where(fn (Builder $q) => $q->whereNull('hold_expires_at')->orWhere('hold_expires_at', '>', now()));
    }
}
