<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Order */
class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'table_id' => $this->table_id,
            'table_number' => $this->whenLoaded('table', fn () => $this->resource->getRelation('table')?->number),
            'customer_id' => $this->customer_id,
            'customer_name' => $this->whenLoaded('customer', fn () => $this->customer?->name),
            // Để thu ngân biết khách còn bao nhiêu điểm có thể dùng khi thanh toán
            'customer_points' => $this->whenLoaded('customer', fn () => $this->customer?->points),
            'staff_id' => $this->staff_id,
            'staff_name' => $this->whenLoaded('staff', fn () => $this->staff?->name),
            'status' => $this->status->value,
            'status_label' => $this->status->getLabel(),
            'payment_status' => $this->payment_status->value,
            'payment_status_label' => $this->payment_status->getLabel(),
            'note' => $this->note ?? '',
            'subtotal' => (float) $this->total_amount,
            'total_quantity' => $this->whenLoaded('items', fn () => $this->items->sum('quantity')),
            'items' => $this->whenLoaded('items', fn () => $this->items->map(fn ($item) => OrderItemResource::make($item)->resolve())->all()),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
