<?php

namespace Tests\Feature;

use App\Enums\InvoiceStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Báo cáo doanh thu (Dashboard / màn Báo cáo) chia ngày theo giờ của quán, khớp file Excel. */
class ReportTimezoneTest extends TestCase
{
    use RefreshDatabase;

    public function test_invoice_after_midnight_vn_counts_for_that_day(): void
    {
        // 13/11 10:00 giờ VN
        $this->travelTo(Carbon::parse('2026-11-13 03:00:00', 'UTC'));
        Sanctum::actingAs(User::create([
            'name' => 'Admin', 'email' => 'a@test.com', 'password' => '123456', 'role' => 'admin', 'status' => 'active',
        ]));

        // 17:30 UTC ngày 12/11 = 00:30 sáng 13/11 giờ VN → phải là doanh thu HÔM NAY
        $order = Order::create(['status' => OrderStatus::Completed, 'payment_status' => PaymentStatus::Paid]);
        Invoice::create([
            'order_id' => $order->id, 'subtotal' => 99000, 'discount' => 0, 'total' => 99000,
            'payment_method' => PaymentMethod::Cash, 'status' => InvoiceStatus::Paid,
            'paid_at' => Carbon::parse('2026-11-12 17:30:00', 'UTC')->setTimezone(config('app.timezone')),
        ]);

        $data = $this->getJson('/api/reports/overview')->assertOk()->json('data');
        $this->assertEquals(99000, $data['today_revenue']);
        $this->assertEquals(0, $data['yesterday_revenue']);
        $this->assertEquals(99000, end($data['revenue_by_day'])['amount']);

        $range = $this->getJson('/api/reports/revenue?from=2026-11-13&to=2026-11-13')->assertOk()->json('data');
        $this->assertEquals(99000, $range['total']);
        $this->getJson('/api/reports/revenue?from=2026-11-13&to=2026-11-14')->assertStatus(422); // ngày mai
    }
}
