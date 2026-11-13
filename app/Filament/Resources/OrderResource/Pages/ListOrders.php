<?php

namespace App\Filament\Resources\OrderResource\Pages;

use App\Filament\Resources\OrderResource;
use App\Services\ReportExporter;
use App\Services\ReportPeriod;
use Filament\Actions\Action;
use Filament\Forms\Components\DatePicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Get;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Support\Carbon;

class ListOrders extends ListRecords
{
    protected static string $resource = OrderResource::class;

    /**
     * Nút "Xuất báo cáo Excel" trên đầu trang Đơn hàng (web quản trị /admin).
     * Cùng lựa chọn với app Admin: theo Ngày / Tháng / Năm; tháng và năm chỉ liệt kê những kỳ
     * đã có doanh thu (ReportPeriod). File giống hệt file app tải về.
     */
    protected function getHeaderActions(): array
    {
        return [
            Action::make('exportReport')
                ->label('Xuất báo cáo Excel')
                ->icon('heroicon-o-arrow-down-tray')
                ->modalHeading('Xuất báo cáo doanh thu')
                ->modalSubmitActionLabel('Tải file Excel')
                ->form([
                    Select::make('type')
                        ->label('Xuất theo')
                        ->options(ReportPeriod::TYPES)
                        ->default('month')
                        ->required()
                        ->live(),
                    DatePicker::make('day')
                        ->label('Ngày')
                        ->native(false)
                        ->displayFormat('d/m/Y')
                        ->maxDate(now(config('restaurant.timezone')))
                        ->default(now(config('restaurant.timezone'))->toDateString())
                        ->visible(fn (Get $get) => $get('type') === 'day')
                        ->required(fn (Get $get) => $get('type') === 'day'),
                    Select::make('month')
                        ->label('Tháng (chỉ những tháng có doanh thu)')
                        ->options(fn () => ReportPeriod::availableMonths())
                        ->default(fn () => array_key_first(ReportPeriod::availableMonths()))
                        ->visible(fn (Get $get) => $get('type') === 'month')
                        ->required(fn (Get $get) => $get('type') === 'month'),
                    Select::make('year')
                        ->label('Năm (chỉ những năm có doanh thu)')
                        ->options(fn () => ReportPeriod::availableYears())
                        ->default(fn () => array_key_first(ReportPeriod::availableYears()))
                        ->visible(fn (Get $get) => $get('type') === 'year')
                        ->required(fn (Get $get) => $get('type') === 'year'),
                ])
                ->action(function (array $data) {
                    $value = match ($data['type']) {
                        'day' => Carbon::parse($data['day'])->format('Y-m-d'),
                        'month' => (string) $data['month'],
                        'year' => (string) $data['year'],
                    };

                    return app(ReportExporter::class)->download(ReportPeriod::make($data['type'], $value));
                }),
        ];
    }
}
