<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Reservation
 */
class ReservationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'          => $this->id,
            'code'        => $this->code,
            'customer_id' => $this->customer_id,

            // Thông tin bàn
            'table_ids'    => $this->table_ids,
            'table_numbers'=> $this->tables()->pluck('number'),
            'area'         => $this->area,
            'capacity'     => $this->tables()->sum('capacity'),

            // Thông tin đặt bàn
            'date_time'   => $this->date_time?->toIso8601String(),
            'guest_count' => $this->guest_count,
            'note'        => $this->note,

            // Trạng thái
            'status'          => $this->status?->value,
            'is_held'         => $this->isHeld(),
            'hold_expires_at' => $this->hold_expires_at?->toIso8601String(),

            // Món đặt trước
            'pre_order_items'   => $this->pre_order_items,
            'pre_order_payment' => $this->pre_order_payment?->value,
            'pre_order_total'   => $this->preOrderTotal(),

            // ── Tiền cọc ──────────────────────────────────────────────────
            'deposit_amount'    => $this->deposit_amount !== null ? (float) $this->deposit_amount : null,
            'deposit_paid_at'   => $this->deposit_paid_at?->toIso8601String(),
            'is_deposit_paid'   => $this->isDepositPaid(),
            // ──────────────────────────────────────────────────────────────
        ];
    }
}
