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
    ];

    protected function casts(): array
    {
        return [
            'status' => OrderStatus::class,
            'payment_status' => PaymentStatus::class,
            'total_amount' => 'decimal:2',
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
     * Chỉ trả bàn nếu bàn vẫn đang gắn với chính đơn này.
     */
    public function releaseTableIfDone(): void
    {
        $finished = $this->status === OrderStatus::Cancelled
            || ($this->status === OrderStatus::Completed && $this->isPaid());

        // Không dùng $this->table: bên trong model nó trỏ tới thuộc tính $table (tên bảng) của Eloquent.
        $table = $this->getRelationValue('table');

        if ($finished && $table && (int) $table->current_order_id === $this->id) {
            $table->release();
        }
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
