<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Models\DiningTable;
use App\Models\Food;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Đơn chưa có món (vd vừa nhận bàn cho khách đặt trước không đặt món) không được gửi bếp / ra món. */
class EmptyOrderStatusTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    public function test_empty_order_cannot_go_to_kitchen_until_items_are_added(): void
    {
        $staff = User::where('email', 'staff@dineflow.com')->firstOrFail();
        Sanctum::actingAs($staff);
        $table = DiningTable::where('status', 'empty')->orderByDesc('id')->firstOrFail();

        // Giống đơn tạo ra khi nhận bàn: chưa có món
        $order = Order::create([
            'table_id' => $table->id,
            'staff_id' => $staff->id,
            'status' => OrderStatus::Placed,
            'payment_status' => PaymentStatus::Unpaid,
        ]);
        $table->occupy($order);

        foreach (['preparing', 'serving', 'completed'] as $status) {
            $this->patchJson("/api/orders/{$order->id}/status", ['status' => $status])
                ->assertStatus(422)
                ->assertJsonPath('status', 'error');
        }
        $this->assertSame(OrderStatus::Placed, $order->fresh()->status);

        // Thêm món vào đơn đang mở của bàn → gửi bếp được
        $food = Food::where('name', 'Cơm sườn nướng')->firstOrFail();
        $this->postJson('/api/orders', ['table_id' => $table->id, 'items' => [['food_id' => $food->id, 'quantity' => 1]]])
            ->assertSuccessful();
        $this->assertSame(1, $order->fresh()->items()->count(), 'Món phải được thêm vào đúng đơn đang mở của bàn');

        $this->patchJson("/api/orders/{$order->id}/status", ['status' => 'preparing'])->assertOk();
    }
}
