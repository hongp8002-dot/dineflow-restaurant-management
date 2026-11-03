<?php

namespace App\Filament\Widgets;

use App\Enums\TableStatus;
use App\Models\DiningTable;
use App\Models\Invoice;
use App\Models\Order;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class StatsOverview extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected static ?string $pollingInterval = '30s';

    protected function getStats(): array
    {
        $paidToday = Invoice::paid()->whereDate('paid_at', today());
        $revenueToday = (float) (clone $paidToday)->sum('total');
        $successOrders = (clone $paidToday)->count();

        $revenueYesterday = (float) Invoice::paid()->whereDate('paid_at', today()->subDay())->sum('total');

        $servingTables = DiningTable::where('status', TableStatus::Serving)->count();
        $totalTables = DiningTable::count();

        return [
            Stat::make('Doanh thu hôm nay', self::money($revenueToday))
                ->description($this->compareWithYesterday($revenueToday, $revenueYesterday))
                ->descriptionIcon($revenueToday >= $revenueYesterday ? 'heroicon-m-arrow-trending-up' : 'heroicon-m-arrow-trending-down')
                ->color($revenueToday >= $revenueYesterday ? 'success' : 'danger'),
            Stat::make('Đơn thành công hôm nay', $successOrders)
                ->description(Order::open()->count() . ' đơn đang xử lý')
                ->descriptionIcon('heroicon-m-clipboard-document-check')
                ->color('info'),
            Stat::make('Bàn đang có khách', "{$servingTables}/{$totalTables}")
                ->description(DiningTable::where('status', TableStatus::Empty)->count() . ' bàn trống')
                ->descriptionIcon('heroicon-m-squares-2x2')
                ->color('warning'),
        ];
    }

    private function compareWithYesterday(float $today, float $yesterday): string
    {
        if ($yesterday <= 0) {
            return 'Hôm qua chưa có doanh thu';
        }

        $percent = round(($today - $yesterday) / $yesterday * 100);

        return ($percent >= 0 ? '+' : '') . $percent . '% so với hôm qua';
    }

    private static function money(float $amount): string
    {
        return number_format($amount, 0, ',', '.') . ' ₫';
    }
}
