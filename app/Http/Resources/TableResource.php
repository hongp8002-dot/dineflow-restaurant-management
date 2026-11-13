<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Bàn ăn. Controller có thể gắn thêm thuộc tính `effective_status` và `next_reservation_at`
 * (bàn trống nhưng sắp có khách đặt thì báo "reserved").
 *
 * @mixin \App\Models\DiningTable
 */
class TableResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'number' => $this->number,
            'area' => $this->area,
            'capacity' => $this->capacity,
            'status' => $this->resource->getAttribute('effective_status') ?? $this->status->value,
            'serving_since' => $this->serving_since?->toIso8601String(),
            'current_order_id' => $this->current_order_id,
            'next_reservation_at' => $this->resource->getAttribute('next_reservation_at'),
            // Lượt đặt đang giữ bàn: mã, giờ, khách, số khách, tiền cọc (chỉ có ở GET /tables)
            'next_reservation' => $this->resource->getAttribute('next_reservation'),
            'is_locked' => (bool) $this->is_locked,
            'is_active' => (bool) $this->is_active,
        ];
    }
}
