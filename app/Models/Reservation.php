<?php

namespace App\Models;

use App\Enums\PaymentMethod;
use App\Enums\ReservationStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Reservation extends Model
{
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
    ];

    protected function casts(): array
    {
        return [
            'table_ids' => 'array',
            'pre_order_items' => 'array',
            'date_time' => 'datetime',
            'hold_expires_at' => 'datetime',
            'guest_count' => 'integer',
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

    /* ---------------- Scopes ---------------- */

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
