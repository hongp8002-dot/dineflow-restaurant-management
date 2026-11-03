<?php

namespace App\Filament\Widgets;

use App\Models\Invoice;
use Filament\Widgets\ChartWidget;

class RevenueChartWidget extends ChartWidget
{
    protected static ?string $heading = 'Doanh thu 7 ngày gần nhất';

    protected static ?int $sort = 2;

    protected static ?string $pollingInterval = '60s';

    protected int|string|array $columnSpan = 'full';

    protected static ?string $maxHeight = '300px';

    protected function getType(): string
    {
        return 'bar';
    }

    protected function getData(): array
    {
        $start = today()->subDays(6);

        // Gom theo ngày bằng PHP để chạy giống nhau trên SQLite / MySQL / PostgreSQL
        $perDay = Invoice::paid()
            ->where('paid_at', '>=', $start)
            ->get(['total', 'paid_at'])
            ->groupBy(fn (Invoice $invoice) => $invoice->paid_at->format('Y-m-d'))
            ->map(fn ($group) => (float) $group->sum('total'));

        $labels = [];
        $values = [];
        for ($i = 0; $i < 7; $i++) {
            $day = $start->copy()->addDays($i);
            $labels[] = $day->format('d/m');
            $values[] = $perDay[$day->format('Y-m-d')] ?? 0;
        }

        return [
            'datasets' => [
                [
                    'label' => 'Doanh thu (₫)',
                    'data' => $values,
                    'backgroundColor' => '#f59e0b',
                    'borderRadius' => 6,
                ],
            ],
            'labels' => $labels,
        ];
    }

    protected function getOptions(): array
    {
        return [
            'plugins' => ['legend' => ['display' => false]],
            'scales' => ['y' => ['beginAtZero' => true]],
        ];
    }
}
