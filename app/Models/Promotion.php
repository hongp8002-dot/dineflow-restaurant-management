<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Promotion extends Model
{
    protected $fillable = [
        'code',
        'title',
        'description',
        'discount_percent',
        'max_discount',
        'min_order_amount',
        'valid_from',
        'valid_to',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'discount_percent' => 'integer',
            'max_discount' => 'decimal:2',
            'min_order_amount' => 'decimal:2',
            'valid_from' => 'datetime',
            'valid_to' => 'datetime',
            'is_active' => 'boolean',
        ];
    }

    public function invoices(): HasMany
    {
        return $this->hasMany(Invoice::class);
    }

    /** Trạng thái hiển thị, khớp PromotionStatus { active, upcoming, expired } bên Flutter. */
    protected function displayStatus(): Attribute
    {
        return Attribute::get(function (): string {
            if (now()->lt($this->valid_from)) {
                return 'upcoming';
            }

            return ($this->is_active && now()->lte($this->valid_to)) ? 'active' : 'expired';
        });
    }

    /** Voucher có áp dụng được cho đơn có giá trị $amount không. */
    public function isApplicableTo(float $amount): bool
    {
        return $this->is_active
            && now()->between($this->valid_from, $this->valid_to)
            && $amount >= (float) $this->min_order_amount;
    }

    /** Số tiền được giảm cho đơn $amount (đã áp trần max_discount). */
    public function calculateDiscount(float $amount): float
    {
        if (! $this->isApplicableTo($amount)) {
            return 0;
        }

        $discount = round($amount * $this->discount_percent / 100);

        return $this->max_discount !== null
            ? min($discount, (float) $this->max_discount)
            : $discount;
    }

    /** Voucher đang trong thời gian hiệu lực. */
    public function scopeValid(Builder $query): Builder
    {
        return $query->where('is_active', true)
            ->where('valid_from', '<=', now())
            ->where('valid_to', '>=', now());
    }
}
