<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderItem extends Model
{
    protected $fillable = [
        'order_id',
        'food_id',
        'food_name',
        'quantity',
        'options',
        'price',
        'note',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'integer',
            'options' => 'array',
            'price' => 'decimal:2',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function food(): BelongsTo
    {
        return $this->belongsTo(Food::class);
    }

    /** Tổng phụ thu từ options (size, topping). Flutter: OrderItem.optionsExtra */
    protected function optionsExtra(): Attribute
    {
        return Attribute::get(fn (): float => (float) collect($this->options ?? [])->sum('price_modifier'));
    }

    /** Đơn giá đã gồm options. Flutter: OrderItem.unitPrice */
    protected function unitPrice(): Attribute
    {
        return Attribute::get(fn (): float => (float) $this->price + $this->options_extra);
    }

    /** Thành tiền dòng. Flutter: OrderItem.total */
    protected function lineTotal(): Attribute
    {
        return Attribute::get(fn (): float => $this->unit_price * $this->quantity);
    }
}
