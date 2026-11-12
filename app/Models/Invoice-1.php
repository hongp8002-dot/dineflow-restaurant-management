<?php

namespace App\Models;

use App\Enums\InvoiceStatus;
use App\Enums\PaymentMethod;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Invoice extends Model
{
    protected $fillable = [
        'order_id',
        'cashier_id',
        'shift_id',
        'promotion_id',
        'subtotal',
        'discount',
        'total',
        'deposit_amount',   // ← tiền cọc đã được khấu trừ (0 nếu không có cọc)
        'payment_method',
        'status',
        'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'subtotal'       => 'decimal:2',
            'discount'       => 'decimal:2',
            'total'          => 'decimal:2',
            'deposit_amount' => 'decimal:2',
            'payment_method' => PaymentMethod::class,
            'status'         => InvoiceStatus::class,
            'paid_at'        => 'datetime',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function cashier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cashier_id');
    }

    public function promotion(): BelongsTo
    {
        return $this->belongsTo(Promotion::class);
    }

    /** Hóa đơn đã thanh toán (dùng cho thống kê doanh thu). */
    public function scopePaid(Builder $query): Builder
    {
        return $query->where('status', InvoiceStatus::Paid);
    }
}
