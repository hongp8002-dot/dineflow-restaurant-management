<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Reservation */
class ReservationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $tables = $this->resource->tables();

        return [
            'id' => $this->id,
            'code' => $this->code,
            'customer_id' => $this->customer_id,
            'table_ids' => $this->table_ids,
            'table_numbers' => $tables->pluck('number')->all(),
            'area' => $this->area,
            'capacity' => $tables->sum('capacity'),
            'date_time' => $this->date_time->toIso8601String(),
            'guest_count' => $this->guest_count,
            'note' => $this->note,
            'status' => $this->status->value,
            'status_label' => $this->status->getLabel(),
            // Đang giữ bàn chờ xác nhận? (hạn giữ bàn, null nếu đã xác nhận)
            'is_held' => $this->resource->isHeld(),
            'hold_expires_at' => $this->hold_expires_at?->toIso8601String(),
            'pre_order_items' => $this->pre_order_items ?? [],
            'pre_order_payment' => $this->pre_order_payment?->value,
            'pre_order_total' => $this->resource->preOrderTotal(),
        ];
    }
}
