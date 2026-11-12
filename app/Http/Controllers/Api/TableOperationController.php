<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Enums\TableStatus;
use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\OrderResource;
use App\Models\DiningTable;
use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Thao tác bàn: Chuyển bàn và Gộp bàn (NV Order + Admin).
 *
 * CHUYỂN BÀN (transfer):
 *   Đơn đang mở của bàn A → chuyển sang bàn B (B phải trống và không bị khóa).
 *   Bàn A được giải phóng về empty, bàn B chuyển sang serving.
 *
 * GỘP BÀN (merge):
 *   Tất cả món của bàn A (source) được thêm vào đơn của bàn B (target).
 *   Đơn bàn A bị hủy, bàn A được giải phóng.
 *   Nếu bàn B chưa có đơn → hoạt động giống chuyển bàn.
 */
class TableOperationController extends ApiController
{
    /**
     * POST /api/tables/{table}/transfer
     *
     * Body: { to_table_id: int }
     *
     * Điều kiện:
     * - Bàn nguồn phải đang serving (có đơn mở).
     * - Bàn đích phải trống (empty), active, không bị khóa.
     */
    public function transfer(Request $request, DiningTable $table): JsonResponse
    {
        $data = $request->validate([
            'to_table_id' => ['required', 'integer', 'exists:tables,id', 'different:table'],
        ]);

        if ($table->status !== TableStatus::Serving || $table->current_order_id === null) {
            return $this->fail('Bàn nguồn phải đang có đơn hàng đang phục vụ.', 422);
        }

        $target = DiningTable::findOrFail($data['to_table_id']);

        if ($target->status !== TableStatus::Empty) {
            return $this->fail("Bàn {$target->number} không trống. Vui lòng chọn bàn khác.", 422);
        }
        if (! $target->is_active) {
            return $this->fail("Bàn {$target->number} đã bị vô hiệu hóa.", 422);
        }
        if ($target->is_locked) {
            return $this->fail("Bàn {$target->number} đang bị khóa.", 422);
        }

        $order = Order::findOrFail($table->current_order_id);

        DB::transaction(function () use ($table, $target, $order) {
            // Cập nhật đơn hàng: gắn sang bàn mới
            $order->update(['table_id' => $target->id]);

            // Giải phóng bàn nguồn
            $table->release();

            // Kích hoạt bàn đích
            $target->occupy($order);
        });

        return $this->ok(
            OrderResource::make($order->fresh())->resolve(request()),
            "Đã chuyển sang bàn {$target->number} thành công"
        );
    }

    /**
     * POST /api/tables/{table}/merge
     *
     * Body: { target_table_id: int }
     *
     * Gộp đơn của bàn hiện tại (source) vào đơn của bàn đích (target).
     * Nếu bàn đích trống → hoạt động giống chuyển bàn.
     */
    public function merge(Request $request, DiningTable $table): JsonResponse
    {
        $data = $request->validate([
            'target_table_id' => ['required', 'integer', 'exists:tables,id', 'different:table'],
        ]);

        if ($table->status !== TableStatus::Serving || $table->current_order_id === null) {
            return $this->fail('Bàn nguồn phải đang có đơn hàng đang phục vụ.', 422);
        }

        $target = DiningTable::findOrFail($data['target_table_id']);

        if (! $target->is_active) {
            return $this->fail("Bàn {$target->number} đã bị vô hiệu hóa.", 422);
        }
        if ($target->is_locked) {
            return $this->fail("Bàn {$target->number} đang bị khóa.", 422);
        }

        $sourceOrder = Order::with('items')->findOrFail($table->current_order_id);

        DB::transaction(function () use ($table, $target, $sourceOrder, $data) {
            if ($target->status === TableStatus::Empty || $target->current_order_id === null) {
                // Bàn đích trống → chuyển bàn đơn giản
                $sourceOrder->update(['table_id' => $target->id]);
                $table->release();
                $target->occupy($sourceOrder);
            } else {
                // Bàn đích có đơn → gộp items vào đơn đích
                $targetOrder = Order::findOrFail($target->current_order_id);

                foreach ($sourceOrder->items as $item) {
                    // Tìm item cùng food + price + note trong đơn đích.
                    // Dùng `price` thay `options_snapshot` (cột không tồn tại).
                    // Cùng price = cùng options combo (vì options ảnh hưởng price).
                    $existing = $targetOrder->items()
                        ->where('food_id', $item->food_id)
                        ->where('price', $item->price)
                        ->where('note', $item->note)
                        ->first();

                    if ($existing) {
                        // Cộng dồn số lượng, không cần cập nhật cột nào khác
                        // vì price và line_total là computed attributes.
                        $existing->increment('quantity', $item->quantity);
                    } else {
                        // Sao chép item sang đơn đích với đúng các cột trong $fillable:
                        // food_id, food_name, quantity, options, price, note.
                        $targetOrder->items()->create([
                            'food_id'   => $item->food_id,
                            'food_name' => $item->food_name,
                            'quantity'  => $item->quantity,
                            'price'     => $item->price,
                            'options'   => $item->options,
                            'note'      => $item->note,
                        ]);
                    }
                }

                // Hủy đơn nguồn và giải phóng bàn nguồn
                $sourceOrder->update(['status' => OrderStatus::Cancelled]);
                $table->release();
            }
        });

        return $this->ok(null, "Đã gộp bàn {$table->number} vào bàn {$target->number} thành công");
    }
}
