<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin \App\Models\Invoice
 */
class InvoiceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $order = $this->whenLoaded('order');

        return [
            'id'           => $this->id,
            'code'         => $this->code ?? ('INV-' . str_pad($this->id, 6, '0', STR_PAD_LEFT)),
            'order_id'     => $this->order_id,
            'order_code'   => $order?->code,
            'table_number' => $order?->table?->number,

            // Items từ order
            'items' => $order
                ? $order->items->map(fn ($item) => [
                    'name'           => $item->menuItem?->name ?? $item->name ?? '—',
                    'quantity'       => $item->quantity,
                    'price'          => (float) $item->price,
                    'options'        => $item->options ?? [],
                    'subtotal'       => (float) $item->price * $item->quantity,
                ])
                : [],

            // Giá trị
            'subtotal'       => (float) $this->subtotal,
            'discount'       => (float) $this->discount,
            'deposit_amount' => (float) ($this->deposit_amount ?? 0),   // ← tiền cọc đã trừ
            'total'          => (float) $this->total,

            // Thông tin thanh toán
            'promotion_code'  => $this->whenLoaded('promotion', fn () => $this->promotion?->code),
            'payment_method'  => $this->payment_method?->value,
            'status'          => $this->status?->value,
            'shift_id'        => $this->shift_id,
            'points_earned'   => $this->additional['points_earned'] ?? null,

            // Thông tin thu ngân
            'cashier_id'   => $this->cashier_id,
            'cashier_name' => $this->whenLoaded('cashier', fn () => $this->cashier?->name),

            'created_at' => $this->created_at?->toIso8601String(),
            'paid_at'    => $this->paid_at?->toIso8601String(),
        ];
    }
}
