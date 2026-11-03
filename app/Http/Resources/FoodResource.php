<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Food */
class FoodResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'category_id' => $this->category_id,
            'name' => $this->name,
            'price' => (float) $this->price,
            'description' => $this->description ?? '',
            'image' => $this->image_url,
            'icon' => $this->icon,
            'color' => $this->color,
            'rating' => (float) $this->rating,
            'is_best_seller' => $this->is_best_seller,
            'is_available' => $this->is_available,
            'options' => $this->whenLoaded('options', fn () => $this->options->map(fn ($o) => [
                'id' => $o->id,
                'group' => $o->group->value,
                'name' => $o->name,
                'price_modifier' => (float) $o->price_modifier,
            ])->all()),
        ];
    }
}
