<?php

namespace App\Filament\Resources;

use App\Enums\ReservationStatus;
use App\Filament\Resources\ReservationResource\Pages;
use App\Models\DiningTable;
use App\Models\Reservation;
use Filament\Forms;
use Filament\Infolists;
use Filament\Infolists\Infolist;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

/**
 * Lịch đặt bàn trên web /admin — cùng dữ liệu và quy tắc với màn Lịch đặt bàn của app
 * (GET /api/reservations, PATCH /api/reservations/{id}/cancel):
 *  - Không hiện lượt khách đang giữ bàn chưa xác nhận (hold_expires_at khác null).
 *  - Trước khi hiện danh sách gọi Reservation::expireStale() (hủy lượt giữ quá hạn / khách không đến).
 *  - Nút "Hủy lượt đặt" dùng chung Reservation::cancelAndNotify() với API: giữ tiền cọc, gửi thông báo cho khách.
 * Admin không nhận bàn ở đây — nhận bàn là việc của NV Order / Thu ngân trên app.
 */
class ReservationResource extends Resource
{
    protected static ?string $model = Reservation::class;

    protected static ?string $navigationIcon = 'heroicon-o-calendar-days';

    protected static ?string $navigationGroup = 'Vận hành';

    protected static ?string $modelLabel = 'lượt đặt bàn';

    protected static ?string $pluralModelLabel = 'Lịch đặt bàn';

    protected static ?int $navigationSort = 3;

    /** Khách tự đặt trên app; admin chỉ xem và hủy. */
    public static function canCreate(): bool
    {
        return false;
    }

    public static function getEloquentQuery(): Builder
    {
        return parent::getEloquentQuery()
            ->with('customer')
            ->whereNull('hold_expires_at');
    }

    private static function money(?float $value): string
    {
        return number_format((float) $value, 0, ',', '.').' ₫';
    }

    private static function tableNames(Reservation $record): string
    {
        return $record->tables()->map(fn (DiningTable $t) => $t->number)->join(', ') ?: '—';
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('date_time')
                    ->label('Giờ đến')
                    ->dateTime('H:i d/m/Y')
                    ->sortable(),
                Tables\Columns\TextColumn::make('code')
                    ->label('Mã')
                    ->searchable(),
                Tables\Columns\TextColumn::make('customer.name')
                    ->label('Khách hàng')
                    ->description(fn (Reservation $record): ?string => $record->customer?->phone)
                    ->searchable(),
                Tables\Columns\TextColumn::make('tables_label')
                    ->label('Bàn')
                    ->state(fn (Reservation $record): string => static::tableNames($record)),
                Tables\Columns\TextColumn::make('guest_count')
                    ->label('Số khách'),
                Tables\Columns\TextColumn::make('status')
                    ->label('Trạng thái')
                    ->badge(),
                Tables\Columns\TextColumn::make('deposit_amount')
                    ->label('Tiền cọc')
                    ->formatStateUsing(fn ($state, Reservation $record): string => $record->isDepositPaid()
                        ? static::money((float) $state)
                        : '—')
                    ->placeholder('—'),
            ])
            ->defaultSort('date_time')
            ->filters([
                // Giống app: mặc định xem lịch của hôm nay
                Tables\Filters\Filter::make('date')
                    ->label('Ngày')
                    ->form([
                        Forms\Components\DatePicker::make('date')
                            ->label('Ngày đến')
                            ->native(false)
                            ->displayFormat('d/m/Y')
                            ->default(now(config('restaurant.timezone'))->toDateString()),
                    ])
                    ->query(fn (Builder $query, array $data) => $query->when(
                        $data['date'] ?? null,
                        fn (Builder $q, $date) => $q->onRestaurantDate($date),
                    ))
                    ->indicateUsing(fn (array $data): ?string => ($data['date'] ?? null)
                        ? 'Ngày '.\Illuminate\Support\Carbon::parse($data['date'])->format('d/m/Y')
                        : null),
                Tables\Filters\SelectFilter::make('status')
                    ->label('Trạng thái')
                    ->options(ReservationStatus::class),
            ])
            ->actions([
                Tables\Actions\ViewAction::make()->label('Chi tiết'),
                Tables\Actions\Action::make('cancel')
                    ->label('Hủy lượt đặt')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->visible(fn (Reservation $record): bool => $record->status === ReservationStatus::Upcoming)
                    ->requiresConfirmation()
                    ->modalHeading(fn (Reservation $record): string => "Hủy lượt đặt {$record->code}?")
                    ->modalDescription(fn (Reservation $record): string => $record->isDepositPaid()
                        ? 'Khách đã cọc '.static::money((float) $record->deposit_amount).'. Hủy thì tiền cọc KHÔNG được hoàn lại. Khách sẽ nhận được thông báo.'
                        : 'Khách sẽ nhận được thông báo lượt đặt đã bị hủy.')
                    ->modalSubmitActionLabel('Hủy lượt đặt')
                    ->action(function (Reservation $record): void {
                        // Kiểm tra lại: có thể lượt đặt vừa được nhận bàn / hủy ở app
                        $record->refresh();
                        if ($record->status !== ReservationStatus::Upcoming) {
                            Notification::make()
                                ->title('Chỉ hủy được lượt đặt đang ở trạng thái "Sắp tới".')
                                ->danger()
                                ->send();

                            return;
                        }

                        $record->cancelAndNotify();

                        Notification::make()
                            ->title("Đã hủy lượt đặt {$record->code}")
                            ->success()
                            ->send();
                    }),
            ])
            ->bulkActions([]);
    }

    public static function infolist(Infolist $infolist): Infolist
    {
        return $infolist->schema([
            Infolists\Components\Section::make('Lượt đặt')
                ->columns(3)
                ->schema([
                    Infolists\Components\TextEntry::make('code')->label('Mã'),
                    Infolists\Components\TextEntry::make('status')->label('Trạng thái')->badge(),
                    Infolists\Components\TextEntry::make('date_time')->label('Giờ đến')->dateTime('H:i d/m/Y'),
                    Infolists\Components\TextEntry::make('customer.name')->label('Khách hàng'),
                    Infolists\Components\TextEntry::make('customer.phone')->label('Số điện thoại')->placeholder('—'),
                    Infolists\Components\TextEntry::make('guest_count')->label('Số khách'),
                    Infolists\Components\TextEntry::make('tables_label')
                        ->label('Bàn')
                        ->state(fn (Reservation $record): string => static::tableNames($record)),
                    Infolists\Components\TextEntry::make('deposit_label')
                        ->label('Tiền cọc')
                        ->state(fn (Reservation $record): string => $record->isDepositPaid()
                            ? static::money((float) $record->deposit_amount).' (đã cọc '.$record->deposit_paid_at->copy()->setTimezone(config('restaurant.timezone'))->format('H:i d/m').')'
                            : 'Không cọc'),
                    Infolists\Components\TextEntry::make('note')->label('Ghi chú')->placeholder('—'),
                ]),
            Infolists\Components\Section::make('Món đặt trước')
                ->visible(fn (Reservation $record): bool => ! empty($record->pre_order_items))
                ->schema([
                    Infolists\Components\RepeatableEntry::make('pre_order_items')
                        ->hiddenLabel()
                        ->columns(4)
                        ->schema([
                            Infolists\Components\TextEntry::make('food_name')->label('Món'),
                            Infolists\Components\TextEntry::make('quantity')->label('SL'),
                            Infolists\Components\TextEntry::make('price')
                                ->label('Đơn giá')
                                ->formatStateUsing(fn ($state): string => static::money((float) $state)),
                            Infolists\Components\TextEntry::make('note')->label('Ghi chú')->placeholder('—'),
                        ]),
                    Infolists\Components\TextEntry::make('pre_order_total')
                        ->label('Tổng món đặt trước')
                        ->state(fn (Reservation $record): string => static::money($record->preOrderTotal())),
                ]),
        ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListReservations::route('/'),
        ];
    }
}
