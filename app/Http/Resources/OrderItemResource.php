<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\OrderItem */
class OrderItemResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $options = $this->options ?? [];

        return [
            'id' => $this->id,
            'food_id' => $this->food_id,
            'food_name' => $this->food_name,
            'price' => (float) $this->price,
            'quantity' => $this->quantity,
            'options' => $options,
            'options_label' => collect($options)->pluck('name')->join(', '),
            'note' => $this->note ?? '',
            'unit_price' => $this->unit_price,
            'total' => $this->line_total,
        ];
    }
}
