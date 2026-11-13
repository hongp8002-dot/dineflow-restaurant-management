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
use OpenSpout\Reader\XLSX\Reader;
use Tests\TestCase;

/** Xuất Excel theo ngày / tháng / năm (giờ của quán), dùng chung web /admin và app Admin. */
class ReportExportTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(Carbon::parse('2026-11-13 10:00:00', 'UTC'));
        $this->seed();
    }

    private function admin(): void
    {
        Sanctum::actingAs(User::where('email', 'admin@dineflow.com')->firstOrFail());
    }

    /** Tạo một hóa đơn đã thanh toán lúc $paidAtUtc (giờ UTC như database lưu). */
    private function invoiceAt(string $paidAtUtc, float $total): Invoice
    {
        $order = Order::create([
            'status' => OrderStatus::Completed,
            'payment_status' => PaymentStatus::Paid,
            'staff_id' => User::where('email', 'staff@dineflow.com')->value('id'),
        ]);

        return Invoice::create([
            'order_id' => $order->id,
            'cashier_id' => User::where('email', 'cashier@dineflow.com')->value('id'),
            'subtotal' => $total,
            'discount' => 0,
            'total' => $total,
            'payment_method' => PaymentMethod::Cash,
            'status' => InvoiceStatus::Paid,
            // Đổi sang múi giờ lưu trong database (config app.timezone) để test đúng ở mọi cấu hình
            'paid_at' => Carbon::parse($paidAtUtc, 'UTC')->setTimezone(config('app.timezone')),
        ]);
    }

    /** Tải file qua link có chữ ký và đọc lại các sheet: [tên sheet => [dòng => [ô...]]]. */
    private function downloadSheets(string $type, string $value): array
    {
        $url = $this->postJson('/api/reports/export-link', ['type' => $type, 'value' => $value])
            ->assertOk()->json('data.url');

        $response = $this->get($url)->assertOk();
        $path = tempnam(sys_get_temp_dir(), 'xlsx');
        file_put_contents($path, file_get_contents($response->baseResponse->getFile()->getPathname()));

        $reader = new Reader();
        $reader->open($path);
        $sheets = [];
        foreach ($reader->getSheetIterator() as $sheet) {
            foreach ($sheet->getRowIterator() as $row) {
                $sheets[$sheet->getName()][] = $row->toArray();
            }
        }
        $reader->close();

        return $sheets;
    }

    public function test_periods_list_only_months_and_years_with_revenue(): void
    {
        $this->invoiceAt('2025-03-10 05:00:00', 100000);
        $this->admin();

        $data = $this->getJson('/api/reports/export-periods')->assertOk()->json('data');

        $months = array_column($data['months'], 'value');
        $this->assertContains('2026-11', $months);
        $this->assertContains('2025-03', $months);
        $this->assertNotContains('2025-04', $months, 'Tháng không có doanh thu thì không được liệt kê');
        $this->assertSame(['2026', '2025'], array_column($data['years'], 'value'));
    }

    public function test_day_export_uses_restaurant_timezone(): void
    {
        // 18:30 UTC ngày 10/11 = 01:30 sáng 11/11 giờ Việt Nam → phải nằm trong báo cáo ngày 11/11
        $this->invoiceAt('2026-11-10 18:30:00', 123000);
        $this->admin();

        $day11 = $this->downloadSheets('day', '2026-11-11');
        $this->assertStringContainsString('11/11/2026 01:30', json_encode($day11['Hóa đơn'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));

        $day10 = $this->downloadSheets('day', '2026-11-10');
        $this->assertStringNotContainsString('123000', json_encode($day10['Hóa đơn']));
    }

    public function test_year_export_has_monthly_sheet(): void
    {
        $this->admin();
        $sheets = $this->downloadSheets('year', '2026');

        $this->assertArrayHasKey('Doanh thu theo tháng', $sheets);
        $this->assertCount(1 + 12 + 1, $sheets['Doanh thu theo tháng']); // tiêu đề + 12 tháng + TỔNG
        $this->assertArrayHasKey('Món bán chạy', $sheets);
    }

    public function test_month_without_revenue_and_future_day_are_rejected(): void
    {
        $this->admin();
        $this->postJson('/api/reports/export-link', ['type' => 'month', 'value' => '2024-01'])->assertStatus(422);
        $this->postJson('/api/reports/export-link', ['type' => 'day', 'value' => '2026-12-01'])->assertStatus(422);
        $this->postJson('/api/reports/export-link', ['type' => 'week', 'value' => '2026-11'])->assertStatus(422);
    }

    public function test_only_admin_gets_link_and_link_cannot_be_tampered(): void
    {
        Sanctum::actingAs(User::where('email', 'cashier@dineflow.com')->firstOrFail());
        $this->postJson('/api/reports/export-link', ['type' => 'month', 'value' => '2026-11'])->assertStatus(403);

        $this->admin();
        $url = $this->postJson('/api/reports/export-link', ['type' => 'month', 'value' => '2026-11'])->json('data.url');

        $this->get(str_replace('2026-11', '2026-10', $url))->assertStatus(403); // sửa tham số
        $this->get(route('reports.export.download', ['type' => 'month', 'value' => '2026-11']))->assertStatus(403); // không chữ ký

        $this->travel(6)->minutes();
        $this->get($url)->assertStatus(403); // hết hạn
    }
}
