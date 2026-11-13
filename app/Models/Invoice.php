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
        'deposit_amount',
        'total',
        'payment_method',
        'status',
        'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'subtotal' => 'decimal:2',
            'discount' => 'decimal:2',
            'deposit_amount' => 'decimal:2',
            'total' => 'decimal:2',
            'payment_method' => PaymentMethod::class,
            'status' => InvoiceStatus::class,
            'paid_at' => 'datetime',
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
    /**
     * Doanh thu của hóa đơn (nhóm chốt 13/11, cách A) = giá trị đơn sau giảm giá
     * = thực thu tại quầy (`total`) + tiền cọc khách đã trả lúc đặt bàn (`deposit_amount`).
     * Dùng cho mọi báo cáo doanh thu (app, web, Excel). Báo cáo CA thì vẫn dùng `total`
     * vì tiền cọc không đi qua ngăn kéo tiền của thu ngân.
     */
    public function revenueAmount(): float
    {
        return (float) $this->total + (float) ($this->deposit_amount ?? 0);
    }

    /** Tổng doanh thu của một danh sách hóa đơn (xem revenueAmount). */
    public static function sumRevenue(iterable $invoices): float
    {
        return (float) collect($invoices)->sum(fn (self $invoice) => $invoice->revenueAmount());
    }

    public function scopePaid(Builder $query): Builder
    {
        return $query->where('status', InvoiceStatus::Paid);
    }
}
