<?php

namespace Tests\Feature;

use App\Enums\InvoiceStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Enums\ShiftStatus;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\Shift;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Doanh thu (nhóm chốt 13/11, cách A) = thực thu tại quầy + tiền cọc = giá trị đơn sau giảm giá.
 * Báo cáo ca vẫn chỉ tính tiền thu tại quầy (tiền cọc không qua ngăn kéo).
 */
class RevenueWithDepositTest extends TestCase
{
    use RefreshDatabase;

    public function test_revenue_includes_deposit_but_shift_cash_does_not(): void
    {
        $this->travelTo(Carbon::parse('2026-11-13 05:00:00', 'UTC')); // 12:00 giờ VN
        $admin = User::create(['name' => 'Admin', 'email' => 'a@test.com', 'password' => '123456', 'role' => 'admin', 'status' => 'active']);
        $cashier = User::create(['name' => 'Thu ngân', 'email' => 'c@test.com', 'password' => '123456', 'role' => 'cashier', 'status' => 'active']);
        $shift = Shift::create(['cashier_id' => $cashier->id, 'status' => ShiftStatus::Open, 'opening_cash' => 0, 'opened_at' => now()]);

        // Đơn 121.000đ, khách đã cọc 60.500đ khi đặt bàn → thu tại quầy 60.500đ (tiền mặt)
        $order = Order::create(['status' => OrderStatus::Completed, 'payment_status' => PaymentStatus::Paid]);
        Invoice::create([
            'order_id' => $order->id, 'cashier_id' => $cashier->id, 'shift_id' => $shift->id,
            'subtotal' => 121000, 'discount' => 0, 'deposit_amount' => 60500, 'total' => 60500,
            'payment_method' => PaymentMethod::Cash, 'status' => InvoiceStatus::Paid, 'paid_at' => now(),
        ]);

        Sanctum::actingAs($admin);
        $overview = $this->getJson('/api/reports/overview')->assertOk()->json('data');
        $this->assertEquals(121000, $overview['today_revenue'], 'Doanh thu phải gồm cả tiền cọc');

        $range = $this->getJson('/api/reports/revenue?from=2026-11-13&to=2026-11-13')->assertOk()->json('data');
        $this->assertEquals(121000, $range['total']);

        // Báo cáo ca: tiền mặt phải có chỉ gồm tiền thu tại quầy
        $this->assertEquals(60500.0, $shift->fresh()->expectedCash());
        $this->assertEquals(60500.0, $shift->fresh()->revenueByMethod()['cash']);
    }
}
