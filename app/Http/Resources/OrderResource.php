<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin \App\Models\Order */
class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        // Đọc tiền cọc từ reservation được load kèm (nếu có).
        // OrderController::RELATIONS đã bao gồm 'reservation' để đảm bảo luôn được load.
        $depositAmount = 0.0;
        $reservation = $this->whenLoaded('reservation');
        // $reservation là giá trị thực khi đã load, không phải MissingValue
        if ($reservation && ! ($reservation instanceof \Illuminate\Http\Resources\MissingValue)) {
            if ($reservation->isDepositPaid()) {
                $depositAmount = (float) $reservation->deposit_amount;
            }
        }

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
            // ID đặt bàn liên kết (nếu đơn được tạo từ lượt đặt bàn của khách).
            'reservation_id' => $this->reservation_id,
            // Tiền cọc được khấu trừ khi thanh toán (từ reservation.deposit_amount nếu đã cọc).
            'deposit_amount' => $depositAmount,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
