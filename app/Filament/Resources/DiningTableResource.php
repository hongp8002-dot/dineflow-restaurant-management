<?php

namespace App\Filament\Resources;

use App\Enums\TableStatus;
use App\Filament\Resources\DiningTableResource\Pages;
use App\Models\DiningTable;
use App\Models\Reservation;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class DiningTableResource extends Resource
{
    protected static ?string $model = DiningTable::class;

    protected static ?string $navigationIcon = 'heroicon-o-squares-2x2';

    protected static ?string $navigationGroup = 'Vận hành';

    protected static ?string $modelLabel = 'bàn';

    protected static ?string $pluralModelLabel = 'Bàn ăn';

    protected static ?int $navigationSort = 1;

    public static function getNavigationBadge(): ?string
    {
        return (string) DiningTable::where('status', TableStatus::Serving)->count() ?: null;
    }

    public static function getNavigationBadgeTooltip(): ?string
    {
        return 'Bàn đang có khách';
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make()
                ->columns(2)
                ->schema([
                    Forms\Components\TextInput::make('number')
                        ->label('Tên bàn')
                        ->placeholder('Bàn 1')
                        ->required()
                        ->unique(ignoreRecord: true)
                        ->maxLength(30),
                    Forms\Components\TextInput::make('area')
                        ->label('Khu vực')
                        ->placeholder('Tầng 1')
                        ->datalist(fn () => DiningTable::query()->distinct()->pluck('area')->all())
                        ->required()
                        ->maxLength(50),
                    Forms\Components\TextInput::make('capacity')
                        ->label('Sức chứa')
                        ->numeric()
                        ->minValue(1)
                        ->default(4)
                        ->suffix('chỗ')
                        ->required(),
                    Forms\Components\Select::make('status')
                        ->label('Trạng thái')
                        ->options(TableStatus::class)
                        ->default(TableStatus::Empty)
                        ->required(),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('number')
                    ->label('Bàn')
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),
                Tables\Columns\TextColumn::make('area')
                    ->label('Khu vực')
                    ->badge()
                    ->color('gray')
                    ->sortable(),
                Tables\Columns\TextColumn::make('capacity')
                    ->label('Sức chứa')
                    ->suffix(' chỗ')
                    ->sortable(),
                // Đổi trạng thái nhanh ngay trên bảng
                Tables\Columns\SelectColumn::make('status')
                    ->label('Trạng thái')
                    ->options(TableStatus::class)
                    ->selectablePlaceholder(false)
                    ->afterStateUpdated(function ($state, DiningTable $record) {
                        // Chuyển về "trống" thì xóa luôn đơn đang gắn với bàn
                        if ($state === TableStatus::Empty->value || $state === TableStatus::Empty) {
                            $record->release();
                        }
                    }),
                Tables\Columns\TextColumn::make('serving_since')
                    ->label('Có khách từ')
                    ->since()
                    ->placeholder('—'),
                Tables\Columns\TextColumn::make('currentOrder.code')
                    ->label('Đơn hiện tại')
                    ->placeholder('—'),
                // Lượt đặt sắp tới trong hôm nay (giờ quán): để Admin biết bàn đặt trước là của khách nào
                Tables\Columns\TextColumn::make('next_reservation')
                    ->label('Đặt trước hôm nay')
                    ->state(function (DiningTable $record): ?string {
                        $tz = config('restaurant.timezone');
                        // Lọc bàn bằng PHP (table_ids là mảng JSON) để chạy được cả MySQL lẫn SQLite khi test
                        $reservation = Reservation::blocking()
                            ->with('customer')
                            ->where('date_time', '>=', now()->subMinutes(Reservation::GRACE_MINUTES))
                            ->onRestaurantDate(now($tz)->toDateString())
                            ->orderBy('date_time')
                            ->get()
                            ->first(fn (Reservation $r) => in_array($record->id, $r->table_ids ?? []));

                        return $reservation
                            ? $reservation->date_time->copy()->setTimezone($tz)->format('H:i')
                                .' · '.$reservation->code.' · '.($reservation->customer?->name ?? '')
                            : null;
                    })
                    ->placeholder('—'),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label('Trạng thái')
                    ->options(TableStatus::class),
                Tables\Filters\SelectFilter::make('area')
                    ->label('Khu vực')
                    ->options(fn () => DiningTable::query()->distinct()->pluck('area', 'area')->all()),
            ])
            ->actions([
                Tables\Actions\Action::make('release')
                    ->label('Giải phóng')
                    ->icon('heroicon-o-arrow-path')
                    ->color('success')
                    ->visible(fn (DiningTable $record) => ! $record->isEmpty())
                    ->requiresConfirmation()
                    ->modalDescription('Đưa bàn về trạng thái trống. Đơn đang gắn với bàn (nếu có) vẫn được giữ.')
                    ->action(function (DiningTable $record) {
                        $record->release();
                        Notification::make()->title("{$record->number} đã về trạng thái trống")->success()->send();
                    }),
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->defaultSort('number')
            ->poll('30s');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListDiningTables::route('/'),
            'create' => Pages\CreateDiningTable::route('/create'),
            'edit' => Pages\EditDiningTable::route('/{record}/edit'),
        ];
    }
}
