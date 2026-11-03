<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Promotion */
class PromotionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'title' => $this->title,
            'description' => $this->description ?? '',
            'discount_percent' => $this->discount_percent,
            'max_discount' => $this->max_discount !== null ? (float) $this->max_discount : null,
            'min_order_amount' => (float) $this->min_order_amount,
            'valid_from' => $this->valid_from->toIso8601String(),
            'valid_to' => $this->valid_to->toIso8601String(),
            'is_active' => $this->is_active,
            'status' => $this->display_status, // active | upcoming | expired
        ];
    }
}
