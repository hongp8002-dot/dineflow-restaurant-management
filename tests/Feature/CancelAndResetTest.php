<?php

namespace Tests\Feature;

use App\Models\DiningTable;
use App\Models\Food;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Nhóm chốt 13/11:
 * - Hủy đơn bắt buộc lý do (Nhập nhầm / Khách bỏ về / Hết món / Khác + ghi chú), lưu người hủy;
 *   Admin xem danh sách đơn đã hủy.
 * - Admin đặt lại mật khẩu NV Order / Thu ngân về 123456.
 */
class CancelAndResetTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    private function as(string $email): User
    {
        $user = User::where('email', $email)->firstOrFail();
        Sanctum::actingAs($user);

        return $user;
    }

    private function tableOrder(): Order
    {
        $this->as('staff@dineflow.com');
        $table = DiningTable::where('status', 'empty')->orderByDesc('id')->firstOrFail();
        $id = $this->postJson('/api/orders', [
            'table_id' => $table->id,
            'items' => [['food_id' => Food::where('name', 'Cơm sườn nướng')->value('id'), 'quantity' => 1]],
        ])->assertCreated()->json('data.id');

        return Order::findOrFail($id);
    }

    public function test_cashier_cancels_with_reason_and_admin_sees_it(): void
    {
        $order = $this->tableOrder();
        $cashier = $this->as('cashier@dineflow.com');

        $this->patchJson("/api/orders/{$order->id}/cancel", [])->assertStatus(422); // thiếu lý do
        $this->patchJson("/api/orders/{$order->id}/cancel", ['reason' => 'other'])->assertStatus(422); // "Khác" thiếu ghi chú
        $this->patchJson("/api/orders/{$order->id}/cancel", ['reason' => 'bay'])->assertStatus(422);

        $data = $this->patchJson("/api/orders/{$order->id}/cancel", ['reason' => 'customer_left', 'note' => 'Khách có việc gấp'])
            ->assertOk()->json('data');
        $this->assertSame('cancelled', $data['status']);
        $this->assertSame('Khách bỏ về', $data['cancel_reason_label']);
        $this->assertSame($cashier->name, $data['cancelled_by_name']);
        $this->assertSame('empty', DiningTable::find($order->table_id)->status->value);

        // Hủy lần 2 bị chặn
        $this->patchJson("/api/orders/{$order->id}/cancel", ['reason' => 'wrong_entry'])->assertStatus(422);

        // Admin xem danh sách đơn đã hủy hôm nay
        $this->as('admin@dineflow.com');
        $list = $this->getJson('/api/admin/cancelled-orders')->assertOk()->json('data');
        $this->assertSame($order->code, $list['orders'][0]['code']);
        $this->assertSame('Khách có việc gấp', $list['orders'][0]['cancel_note']);

        // Thu ngân không xem được danh sách này
        $this->as('cashier@dineflow.com');
        $this->getJson('/api/admin/cancelled-orders')->assertStatus(403);
    }

    public function test_order_staff_cannot_cancel(): void
    {
        $order = $this->tableOrder(); // đang đăng nhập NV Order
        $this->patchJson("/api/orders/{$order->id}/cancel", ['reason' => 'wrong_entry'])->assertStatus(403);
        $this->patchJson("/api/orders/{$order->id}/status", ['status' => 'cancelled'])->assertStatus(422);
        $this->assertSame('placed', $order->fresh()->status->value);
    }

    public function test_admin_resets_staff_password_only(): void
    {
        $staff = User::where('email', 'staff@dineflow.com')->firstOrFail();
        $staff->update(['password' => 'matkhaumoi']);
        $staff->createToken('may-cu');

        $this->as('cashier@dineflow.com');
        $this->patchJson("/api/admin/users/{$staff->id}/reset-password")->assertStatus(403); // không phải Admin

        $this->as('admin@dineflow.com');
        $this->patchJson("/api/admin/users/{$staff->id}/reset-password")->assertOk();
        $this->assertTrue(Hash::check('123456', $staff->fresh()->password));
        $this->assertSame(0, $staff->tokens()->count(), 'Đặt lại xong phải đăng xuất mọi thiết bị');

        $customer = User::where('email', 'customer@dineflow.com')->firstOrFail();
        $this->patchJson("/api/admin/users/{$customer->id}/reset-password")->assertStatus(422); // khách dùng Quên mật khẩu
        $admin = User::where('email', 'admin@dineflow.com')->firstOrFail();
        $this->patchJson("/api/admin/users/{$admin->id}/reset-password")->assertStatus(422);
    }
}
