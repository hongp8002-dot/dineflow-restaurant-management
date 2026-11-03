<?php

namespace App\Models;

use App\Enums\FoodOptionGroup;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class FoodOption extends Model
{
    protected $fillable = ['food_id', 'name', 'group', 'price_modifier'];

    protected function casts(): array
    {
        return [
            'group' => FoodOptionGroup::class,
            'price_modifier' => 'decimal:2',
        ];
    }

    public function food(): BelongsTo
    {
        return $this->belongsTo(Food::class);
    }

    /** Snapshot lưu vào order_items.options / reservations.pre_order_items. */
    public function toSnapshot(): array
    {
        return [
            'id' => $this->id,
            'group' => $this->group->value,
            'name' => $this->name,
            'price_modifier' => (float) $this->price_modifier,
        ];
    }
}
