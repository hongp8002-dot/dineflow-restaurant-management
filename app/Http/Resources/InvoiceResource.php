<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Invoice */
class InvoiceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $order = $this->order;

        // Điểm khách được cộng cho hóa đơn này (quy tắc Kiểu A trong config/loyalty.php)
        $pointsEarned = \App\Services\LoyaltyRules::pointsEarned((float) $this->total);

        return [
            'id'             => $this->id,
            'code'           => sprintf('HD%05d', $this->id),
            'order_id'       => $this->order_id,
            'order_code'     => $order?->code,
            'table_number'   => $order?->getRelationValue('table')?->number,
            'items'          => $order
                ? $order->items->map(fn ($item) => OrderItemResource::make($item)->resolve())->all()
                : [],
            'subtotal'       => (float) $this->subtotal,
            'discount'       => (float) $this->discount,
            // Tiền cọc được khấu trừ trong hóa đơn này (từ đặt bàn kèm món trước).
            'deposit_amount' => (float) ($this->deposit_amount ?? 0),
            'total'          => (float) $this->total,
            'promotion_code' => $this->promotion?->code,
            'payment_method' => $this->payment_method?->value,
            'status'         => $this->status->value,
            'shift_id'       => $this->shift_id,
            'points_earned'  => $pointsEarned,
            'paid_at'        => $this->paid_at?->toIso8601String(),
            'created_at'     => ($this->paid_at ?? $this->created_at)?->toIso8601String(),
            'cashier_id'     => $this->cashier_id,
            'cashier_name'   => $this->cashier?->name,
        ];
    }
}
