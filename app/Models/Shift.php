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
