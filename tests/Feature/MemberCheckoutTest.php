<?php

namespace Tests\Feature;

use App\Models\DiningTable;
use App\Models\Food;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Thu ngân quét / nhập mã thành viên cho đơn tại bàn (NV Order tạo, chưa gắn khách):
 * server phải gắn khách vào đơn, giảm theo hạng (Kiểu A) và cộng điểm theo số tiền thực trả.
 */
class MemberCheckoutTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    /** NV Order tạo đơn tại một bàn trống: 2 × Cơm sườn nướng. Trả về [id đơn, tạm tính]. */
    private function tableOrder(): array
    {
        Sanctum::actingAs(User::where('email', 'staff@dineflow.com')->firstOrFail());
        $food = Food::where('name', 'Cơm sườn nướng')->firstOrFail();
        $table = DiningTable::where('status', 'empty')->orderByDesc('id')->firstOrFail();

        $order = $this->postJson('/api/orders', [
            'table_id' => $table->id,
            'items' => [['food_id' => $food->id, 'quantity' => 2]],
        ])->assertCreated()->json('data');

        return [$order['id'], (float) $food->price * 2];
    }

    private function cashierWithOpenShift(): void
    {
        Sanctum::actingAs(User::where('email', 'cashier@dineflow.com')->firstOrFail());
        $this->postJson('/api/shifts', ['opening_cash' => 500000])->assertCreated();
    }

    public function test_member_code_attaches_customer_and_earns_points(): void
    {
        [$orderId, $subtotal] = $this->tableOrder();
        $customer = User::where('email', 'customer@dineflow.com')->firstOrFail(); // 320 điểm, hạng Bạc (0%)
        $before = $customer->points;

        $this->cashierWithOpenShift();
        $invoice = $this->postJson("/api/orders/{$orderId}/pay", [
            'payment_method' => 'cash',
            'member_code' => strtolower($customer->member_code), // nhập thường cũng được
        ])->assertOk()->json('data');

        $customer->refresh();
        $expectedPoints = intdiv((int) $subtotal, 10000) * 2; // config/loyalty.php: 2 điểm / 10.000đ
        $this->assertSame((float) $subtotal, (float) $invoice['total']);
        $this->assertSame($before + $expectedPoints, $customer->points);
        $this->assertSame($customer->id, \App\Models\Order::find($orderId)->customer_id);
    }

    public function test_gold_member_gets_tier_discount(): void
    {
        [$orderId, $subtotal] = $this->tableOrder();
        $customer = User::where('email', 'customer@dineflow.com')->firstOrFail();
        $customer->update(['points' => 600]); // hạng Vàng: giảm 5%

        $this->cashierWithOpenShift();
        $invoice = $this->postJson("/api/orders/{$orderId}/pay", [
            'payment_method' => 'cash',
            'member_code' => $customer->member_code,
        ])->assertOk()->json('data');

        $this->assertEqualsWithDelta($subtotal * 0.95, (float) $invoice['total'], 0.01);
    }

    public function test_unknown_member_code_is_rejected_and_nothing_is_paid(): void
    {
        [$orderId] = $this->tableOrder();
        $this->cashierWithOpenShift();

        $this->postJson("/api/orders/{$orderId}/pay", ['payment_method' => 'cash', 'member_code' => 'DF-KHONGCO'])
            ->assertStatus(422)
            ->assertJsonPath('status', 'error');

        $this->assertSame('unpaid', \App\Models\Order::find($orderId)->payment_status->value);
        $this->assertNull(\App\Models\Order::find($orderId)->customer_id);
    }

    public function test_cannot_switch_order_to_another_member(): void
    {
        [$orderId] = $this->tableOrder();
        $owner = User::where('email', 'customer@dineflow.com')->firstOrFail();
        \App\Models\Order::find($orderId)->update(['customer_id' => $owner->id]);

        $other = User::create([
            'name' => 'Khách khác', 'email' => 'khac@test.com', 'phone' => '0933333333',
            'password' => '123456', 'role' => 'customer', 'status' => 'active', 'member_code' => 'DF-MB9999',
        ]);

        $this->cashierWithOpenShift();
        $this->postJson("/api/orders/{$orderId}/pay", ['payment_method' => 'cash', 'member_code' => $other->member_code])
            ->assertStatus(422);

        // Cùng khách đã gắn thì vẫn thanh toán bình thường
        $this->postJson("/api/orders/{$orderId}/pay", ['payment_method' => 'cash', 'member_code' => $owner->member_code])
            ->assertOk();
    }
}
