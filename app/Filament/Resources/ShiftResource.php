<?php

namespace App\Filament\Resources;

use App\Enums\ShiftStatus;
use App\Filament\Resources\ShiftResource\Pages;
use App\Models\Shift;
use Filament\Forms;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;

/**
 * Báo cáo ca trên web /admin (chỉ xem) — cùng số liệu với màn Báo cáo ca của app Admin
 * (GET /api/shifts): doanh thu theo phương thức = Shift::revenueByMethod(),
 * tiền mặt phải có = Shift::expectedCash(), chênh lệch = Shift::cashDifference().
 */
class ShiftResource extends Resource
{
    protected static ?string $model = Shift::class;

    protected static ?string $navigationIcon = 'heroicon-o-identification';

    protected static ?string $navigationGroup = 'Vận hành';

    protected static ?string $modelLabel = 'ca làm';

    protected static ?string $pluralModelLabel = 'Báo cáo ca';

    protected static ?int $navigationSort = 4;

    /** Ca chỉ được mở / đóng bởi thu ngân trên app; ở đây chỉ xem lại. */
    public static function canCreate(): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        $money = fn (?float $value): string => $value === null ? '—' : number_format($value, 0, ',', '.').' ₫';

        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->with('cashier')->withCount('invoices'))
            ->columns([
                Tables\Columns\TextColumn::make('cashier.name')
                    ->label('Thu ngân')
                    ->searchable(),
                Tables\Columns\TextColumn::make('status')
                    ->label('Trạng thái')
                    ->badge()
                    ->formatStateUsing(fn (ShiftStatus $state): string => $state === ShiftStatus::Open ? 'Đang mở' : 'Đã đóng')
                    ->color(fn (ShiftStatus $state): string => $state === ShiftStatus::Open ? 'info' : 'success'),
                Tables\Columns\TextColumn::make('opened_at')
                    ->label('Mở ca')
                    ->dateTime('d/m/Y H:i')
                    ->sortable(),
                Tables\Columns\TextColumn::make('closed_at')
                    ->label('Đóng ca')
                    ->dateTime('d/m/Y H:i')
                    ->placeholder('đang mở'),
                Tables\Columns\TextColumn::make('invoices_count')
                    ->label('Hóa đơn'),
                Tables\Columns\TextColumn::make('opening_cash')
                    ->label('Tiền đầu ca')
                    ->formatStateUsing(fn ($state) => $money((float) $state)),
                Tables\Columns\TextColumn::make('revenue_cash')
                    ->label('Tiền mặt')
                    ->state(fn (Shift $record): float => $record->revenueByMethod()['cash'])
                    ->formatStateUsing(fn ($state) => $money((float) $state)),
                Tables\Columns\TextColumn::make('revenue_qr')
                    ->label('QR')
                    ->state(fn (Shift $record): float => $record->revenueByMethod()['qr'])
                    ->formatStateUsing(fn ($state) => $money((float) $state)),
                Tables\Columns\TextColumn::make('revenue_card')
                    ->label('Thẻ')
                    ->state(fn (Shift $record): float => $record->revenueByMethod()['card'])
                    ->formatStateUsing(fn ($state) => $money((float) $state)),
                Tables\Columns\TextColumn::make('expected_cash')
                    ->label('Tiền mặt phải có')
                    ->state(fn (Shift $record): float => $record->expectedCash())
                    ->formatStateUsing(fn ($state) => $money((float) $state)),
                Tables\Columns\TextColumn::make('closing_cash_counted')
                    ->label('Đếm được')
                    ->formatStateUsing(fn ($state) => $money($state === null ? null : (float) $state))
                    ->placeholder('—'),
                Tables\Columns\TextColumn::make('cash_difference')
                    ->label('Chênh lệch')
                    ->state(fn (Shift $record): ?float => $record->cashDifference())
                    ->formatStateUsing(fn ($state): string => match (true) {
                        $state === null => '—',
                        (float) $state == 0.0 => 'Khớp',
                        (float) $state < 0 => 'Thiếu '.$money(-(float) $state),
                        default => 'Thừa '.$money((float) $state),
                    })
                    ->placeholder('—')
                    ->badge()
                    ->color(fn ($state): string => match (true) {
                        $state === null => 'gray',
                        (float) $state == 0.0 => 'success',
                        (float) $state < 0 => 'danger',
                        default => 'warning',
                    }),
            ])
            ->defaultSort('opened_at', 'desc')
            ->filters([
                // Giống app: xem các ca MỞ trong một ngày
                Tables\Filters\Filter::make('opened_on')
                    ->label('Ngày mở ca')
                    ->form([
                        Forms\Components\DatePicker::make('date')
                            ->label('Ngày mở ca')
                            ->native(false)
                            ->displayFormat('d/m/Y'),
                    ])
                    ->query(fn (Builder $query, array $data) => $query->when(
                        $data['date'] ?? null,
                        function (Builder $q, $date) {
                            // Ngày theo giờ của quán; database lưu UTC
                            $start = Carbon::parse($date, config('restaurant.timezone'))->startOfDay()->setTimezone(config('app.timezone'));

                            return $q->where('opened_at', '>=', $start)->where('opened_at', '<', $start->copy()->addDay());
                        },
                    )),
                Tables\Filters\SelectFilter::make('cashier_id')
                    ->label('Thu ngân')
                    ->relationship('cashier', 'name'),
                Tables\Filters\SelectFilter::make('status')
                    ->label('Trạng thái')
                    ->options(['open' => 'Đang mở', 'closed' => 'Đã đóng']),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListShifts::route('/'),
        ];
    }
}
