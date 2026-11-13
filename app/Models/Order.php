<?php

namespace App\Models;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Order extends Model
{
    protected $fillable = [
        'code',
        'table_id',
        'customer_id',
        'staff_id',
        'reservation_id',
        'status',
        'payment_status',
        'note',
        'total_amount',
        'cancel_reason',
        'cancel_note',
        'cancelled_by',
        'cancelled_at',
    ];

    protected function casts(): array
    {
        return [
            'status' => OrderStatus::class,
            'payment_status' => PaymentStatus::class,
            'total_amount' => 'decimal:2',
            'cancel_reason' => \App\Enums\CancelReason::class,
            'cancelled_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Order $order) {
            $order->code ??= static::generateCode();
        });
    }

    /** Mã đơn dạng OD241008-4821. */
    public static function generateCode(): string
    {
        do {
            $code = 'OD' . now()->format('ymd') . '-' . random_int(1000, 9999);
        } while (static::where('code', $code)->exists());

        return $code;
    }

    /* ---------------- Relationships ---------------- */

    public function table(): BelongsTo
    {
        return $this->belongsTo(DiningTable::class, 'table_id');
    }

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    public function staff(): BelongsTo
    {
        return $this->belongsTo(User::class, 'staff_id');
    }

    public function reservation(): BelongsTo
    {
        return $this->belongsTo(Reservation::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function invoice(): HasOne
    {
        return $this->hasOne(Invoice::class);
    }

    /* ---------------- Business helpers ---------------- */

    /** Tính lại tổng tiền từ order_items và lưu vào total_amount. */
    public function recalculateTotal(): static
    {
        $this->loadMissing('items');
        $this->total_amount = $this->items->sum(fn (OrderItem $item) => $item->line_total);
        $this->save();

        return $this;
    }

    public function isPaid(): bool
    {
        return $this->payment_status === PaymentStatus::Paid;
    }

    /**
     * Trả bàn về trống khi đơn đã kết thúc: bị hủy, hoặc hoàn thành và đã thanh toán.
     *
     * Trả MỌI bàn đang gắn với chính đơn này (current_order_id = id đơn): khách đặt ghép
     * nhiều bàn (vd Bàn 3 + Bàn 4) thì khi nhận bàn cả hai cùng trỏ tới một đơn.
     * Bàn đã chuyển sang đơn khác thì không bị đụng tới.
     */
    /**
     * Lý do không được chuyển đơn sang trạng thái $to, hoặc null nếu được.
     * Đơn chưa có món (vd vừa nhận bàn cho khách đặt trước không đặt món) thì chưa được gửi bếp /
     * ra món / hoàn thành — chỉ được thêm món hoặc hủy. Dùng chung cho API (app) và web /admin.
     */
    public function statusChangeBlockedReason(OrderStatus $to): ?string
    {
        $kitchenSteps = [OrderStatus::Preparing, OrderStatus::Serving, OrderStatus::Completed];

        if (in_array($to, $kitchenSteps, true) && $this->items()->doesntExist()) {
            return "Đơn {$this->code} chưa có món nào. Hãy thêm món trước khi chuyển sang \"{$to->getLabel()}\".";
        }

        return null;
    }

    /** Người đã hủy đơn (Thu ngân / Admin). */
    public function cancelledBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cancelled_by');
    }

    /**
     * Hủy đơn kèm lý do (nhóm chốt 13/11, cách A). Dùng chung cho API của app (Thu ngân / Admin)
     * và nút Hủy đơn trên web /admin. Chỉ hủy được đơn chưa thanh toán, chưa hoàn thành, chưa hủy.
     * Lưu lý do, ghi chú, người hủy, thời điểm; trả mọi bàn của đơn về trống.
     *
     * @throws \Illuminate\Validation\ValidationException
     */
    public function cancelBy(User $by, \App\Enums\CancelReason $reason, ?string $note = null): void
    {
        $fail = fn (string $message) => throw \Illuminate\Validation\ValidationException::withMessages(['order' => $message]);
        $note = filled($note) ? trim($note) : null;

        if ($this->isPaid()) {
            $fail('Đơn đã thanh toán không thể hủy.');
        }
        if ($this->status === OrderStatus::Cancelled) {
            $fail('Đơn này đã được hủy trước đó.');
        }
        if ($this->status === OrderStatus::Completed) {
            $fail('Đơn đã hoàn thành không thể hủy.');
        }
        if ($reason === \App\Enums\CancelReason::Other && $note === null) {
            throw \Illuminate\Validation\ValidationException::withMessages(['note' => 'Chọn lý do "Khác" thì phải ghi rõ lý do.']);
        }

        $this->update([
            'status' => OrderStatus::Cancelled,
            'cancel_reason' => $reason,
            'cancel_note' => $note,
            'cancelled_by' => $by->id,
            'cancelled_at' => now(),
        ]);

        // Giải phóng mọi bàn đang gắn với đơn này (kể cả bàn ghép khi nhận bàn đặt trước)
        $this->releaseTableIfDone();
    }

    public function releaseTableIfDone(): void
    {
        $finished = $this->status === OrderStatus::Cancelled
            || ($this->status === OrderStatus::Completed && $this->isPaid());

        if (! $finished) {
            return;
        }

        DiningTable::where('current_order_id', $this->id)->get()->each->release();
    }

    /* ---------------- Scopes ---------------- */

    public function scopeOpen(Builder $query): Builder
    {
        return $query->whereIn('status', [OrderStatus::Placed, OrderStatus::Preparing, OrderStatus::Serving]);
    }

    public function scopePaid(Builder $query): Builder
    {
        return $query->where('payment_status', PaymentStatus::Paid);
    }
}
