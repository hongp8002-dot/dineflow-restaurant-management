<?php

namespace App\Services;

use App\Models\Invoice;
use App\Models\OrderItem;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use OpenSpout\Common\Entity\Row;
use OpenSpout\Writer\XLSX\Writer;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Xuất báo cáo doanh thu ra file Excel (.xlsx) theo một kỳ (ngày / tháng / năm, xem ReportPeriod).
 * Dùng chung cho web /admin và app Admin (qua link tải có chữ ký) → hai nơi ra cùng một file.
 *
 * Các sheet:
 *   1. Hóa đơn              – hóa đơn đã thanh toán trong kỳ.
 *   2. Doanh thu theo ngày  – mỗi ngày trong kỳ (kể cả ngày không có hóa đơn).
 *   3. Doanh thu theo tháng – chỉ khi xuất theo NĂM (12 dòng, dễ đọc hơn 365 dòng theo ngày).
 *   4. Món bán chạy         – số lượng và doanh thu từng món (chưa trừ khuyến mãi).
 *
 * Ngày / tháng tính theo giờ của quán (config restaurant.timezone); database lưu UTC.
 * Doanh thu = Invoice::revenueAmount() (thực thu tại quầy + tiền cọc), giống ReportController.
 * Dùng thư viện OpenSpout đã có sẵn trong project (Filament phụ thuộc vào nó), không cài thêm.
 */
class ReportExporter
{
    public function download(ReportPeriod $period): BinaryFileResponse
    {
        $tz = config('restaurant.timezone');

        $invoices = Invoice::paid()
            ->with(['order.table', 'cashier', 'promotion'])
            ->where('paid_at', '>=', $period->startForDb())
            ->where('paid_at', '<', $period->endForDb())
            ->orderBy('paid_at')
            ->get();

        $path = tempnam(sys_get_temp_dir(), 'dineflow-report-');
        $writer = new Writer();
        $writer->openToFile($path);

        $this->writeInvoices($writer, $invoices, $tz, $period);
        $this->writeRevenueByDay($writer, $invoices, $period, $tz);
        if ($period->type === 'year') {
            $this->writeRevenueByMonth($writer, $invoices, $period, $tz);
        }
        $this->writeTopFoods($writer, $period);

        $writer->close();

        return response()->download($path, $period->fileName())->deleteFileAfterSend();
    }

    /** Ngày (giờ của quán) của một hóa đơn. */
    private function localPaidAt(Invoice $invoice, string $tz): Carbon
    {
        return $invoice->paid_at->copy()->setTimezone($tz);
    }

    /** @param Collection<int, Invoice> $invoices */
    private function writeInvoices(Writer $writer, Collection $invoices, string $tz, ReportPeriod $period): void
    {
        $writer->getCurrentSheet()->setName('Hóa đơn');
        $writer->addRow(Row::fromValues(['Báo cáo doanh thu DineFlow – '.$period->label]));
        $writer->addRow(Row::fromValues([
            'Mã hóa đơn', 'Mã đơn', 'Thời gian thanh toán', 'Bàn', 'Thu ngân',
            'Tạm tính', 'Giảm giá', 'Mã khuyến mãi', 'Tiền cọc (trả khi đặt bàn)', 'Thực thu tại quầy',
            'Doanh thu (gồm cọc)', 'Phương thức',
        ]));

        foreach ($invoices as $invoice) {
            $writer->addRow(Row::fromValues([
                sprintf('HD%05d', $invoice->id),
                $invoice->order?->code ?? '',
                $invoice->paid_at ? $this->localPaidAt($invoice, $tz)->format('d/m/Y H:i') : '',
                $invoice->order?->getRelationValue('table')?->number ?? 'Đặt qua app',
                $invoice->cashier?->name ?? '',
                (float) $invoice->subtotal,
                (float) $invoice->discount,
                $invoice->promotion?->code ?? '',
                (float) ($invoice->deposit_amount ?? 0),
                (float) $invoice->total,
                $invoice->revenueAmount(),
                $invoice->payment_method?->getLabel() ?? '',
            ]));
        }

        $writer->addRow(Row::fromValues([
            'TỔNG', '', '', '', '',
            (float) $invoices->sum('subtotal'),
            (float) $invoices->sum('discount'),
            '',
            (float) $invoices->sum('deposit_amount'),
            (float) $invoices->sum('total'),
            Invoice::sumRevenue($invoices),
            $invoices->count().' hóa đơn',
        ]));
    }

    /** @param Collection<int, Invoice> $invoices */
    private function writeRevenueByDay(Writer $writer, Collection $invoices, ReportPeriod $period, string $tz): void
    {
        $writer->addNewSheetAndMakeItCurrent()->setName('Doanh thu theo ngày');
        $writer->addRow(Row::fromValues(['Ngày', 'Số hóa đơn', 'Doanh thu (gồm cọc)']));

        $byDay = $invoices->groupBy(fn (Invoice $i) => $this->localPaidAt($i, $tz)->toDateString());
        // Không kéo tới tương lai: tháng / năm hiện tại chỉ liệt kê tới hôm nay
        $last = min($period->end->copy(), now($tz)->startOfDay()->addDay());

        for ($day = $period->start->copy(); $day->lt($last); $day->addDay()) {
            $rows = $byDay->get($day->toDateString(), collect());
            $writer->addRow(Row::fromValues([$day->format('d/m/Y'), $rows->count(), Invoice::sumRevenue($rows)]));
        }

        $writer->addRow(Row::fromValues(['TỔNG', $invoices->count(), Invoice::sumRevenue($invoices)]));
    }

    /** @param Collection<int, Invoice> $invoices */
    private function writeRevenueByMonth(Writer $writer, Collection $invoices, ReportPeriod $period, string $tz): void
    {
        $writer->addNewSheetAndMakeItCurrent()->setName('Doanh thu theo tháng');
        $writer->addRow(Row::fromValues(['Tháng', 'Số hóa đơn', 'Doanh thu (gồm cọc)']));

        $byMonth = $invoices->groupBy(fn (Invoice $i) => $this->localPaidAt($i, $tz)->format('Y-m'));

        for ($month = $period->start->copy(); $month->lt($period->end); $month->addMonth()) {
            $rows = $byMonth->get($month->format('Y-m'), collect());
            $writer->addRow(Row::fromValues([$month->format('m/Y'), $rows->count(), Invoice::sumRevenue($rows)]));
        }

        $writer->addRow(Row::fromValues(['TỔNG', $invoices->count(), Invoice::sumRevenue($invoices)]));
    }

    private function writeTopFoods(Writer $writer, ReportPeriod $period): void
    {
        $writer->addNewSheetAndMakeItCurrent()->setName('Món bán chạy');
        $writer->addRow(Row::fromValues(['Hạng', 'Món', 'Số lượng bán', 'Doanh thu món (chưa trừ khuyến mãi)']));

        $foods = OrderItem::whereHas('order.invoice', fn ($q) => $q->paid()
            ->where('paid_at', '>=', $period->startForDb())
            ->where('paid_at', '<', $period->endForDb()))
            ->get()
            ->groupBy('food_name')
            ->map(fn (Collection $rows, string $name) => [
                'name' => $name,
                'quantity' => (int) $rows->sum('quantity'),
                'revenue' => (float) $rows->sum(fn (OrderItem $item) => $item->line_total),
            ])
            ->sortByDesc('quantity')
            ->values();

        foreach ($foods as $i => $food) {
            $writer->addRow(Row::fromValues([$i + 1, $food['name'], $food['quantity'], $food['revenue']]));
        }
    }
}
