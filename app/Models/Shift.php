<?php

namespace App\Models;

use App\Enums\ShiftStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Shift extends Model
{
    protected $fillable = [
        'cashier_id',
        'status',
        'opening_cash',
        'closing_cash_counted',
        'opened_at',
        'closed_at',
    ];

    protected function casts(): array
    {
        return [
            'status'                 => ShiftStatus::class,
            'opening_cash'           => 'decimal:2',
            'closing_cash_counted'   => 'decimal:2',
            'opened_at'              => 'datetime',
            'closed_at'              => 'datetime',
        ];
    }

    /* ── Relationships ─────────────────────────────────── */

    public function cashier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cashier_id');
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(Invoice::class);
    }

    /* ── Scopes ────────────────────────────────────────── */

    public function scopeOpen(Builder $query): Builder
    {
        return $query->where('status', ShiftStatus::Open);
    }

    /* ── Helpers ───────────────────────────────────────── */

    public function isOpen(): bool
    {
        return $this->status === ShiftStatus::Open;
    }

    /**
     * Doanh thu trong ca theo phương thức: ['cash' => …, 'qr' => …, 'card' => …].
     * Dùng chung cho API báo cáo ca (app) và trang Báo cáo ca trên web /admin.
     *
     * @return array{cash: float, qr: float, card: float}
     */
    public function revenueByMethod(): array
    {
        $invoices = $this->invoices()->get(['payment_method', 'total']);
        $byMethod = [];
        foreach (['cash', 'qr', 'card'] as $method) {
            // So sánh qua ->value: cột đã cast sang enum PaymentMethod nên không so trực tiếp với chuỗi.
            $byMethod[$method] = (float) $invoices
                ->filter(fn ($invoice) => $invoice->payment_method?->value === $method)
                ->sum('total');
        }

        return $byMethod;
    }

    /** Chênh lệch tiền mặt khi đóng ca = đếm được − phải có; null nếu ca chưa đóng. */
    public function cashDifference(): ?float
    {
        return $this->closing_cash_counted !== null
            ? (float) $this->closing_cash_counted - $this->expectedCash()
            : null;
    }

    /**
     * Tổng tiền mặt phải có khi đóng ca:
     *   đầu ca + thu tiền mặt trong ca − hoàn tiền mặt (hiện chưa có hoàn tiền)
     */
    public function expectedCash(): float
    {
        $cashRevenue = (float) $this->invoices()
            ->where('payment_method', 'cash')
            ->sum('total');

        return (float) $this->opening_cash + $cashRevenue;
    }
}
