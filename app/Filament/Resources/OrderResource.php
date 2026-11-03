<?php

namespace App\Filament\Resources;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Filament\Resources\OrderResource\Pages;
use App\Filament\Resources\OrderResource\RelationManagers\ItemsRelationManager;
use App\Models\Order;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class OrderResource extends Resource
{
    protected static ?string $model = Order::class;

    protected static ?string $navigationIcon = 'heroicon-o-clipboard-document-list';

    protected static ?string $navigationGroup = 'Vận hành';

    protected static ?string $modelLabel = 'đơn hàng';

    protected static ?string $pluralModelLabel = 'Đơn hàng';

    protected static ?int $navigationSort = 2;

    protected static ?string $recordTitleAttribute = 'code';

    /** Đơn do nhân viên/khách tạo qua app, admin chỉ theo dõi và đổi trạng thái. */
    public static function canCreate(): bool
    {
        return false;
    }

    public static function getNavigationBadge(): ?string
    {
        return (string) Order::open()->count() ?: null;
    }

    public static function getNavigationBadgeTooltip(): ?string
    {
        return 'Đơn đang xử lý';
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('Đơn hàng')
                ->columns(3)
                ->schema([
                    Forms\Components\TextInput::make('code')->label('Mã đơn')->disabled(),
                    Forms\Components\Select::make('table_id')->label('Bàn')->relationship('table', 'number')->disabled(),
                    Forms\Components\TextInput::make('total_amount')->label('Tổng tiền')->suffix('₫')->disabled(),
                    Forms\Components\Select::make('staff_id')->label('Nhân viên tạo đơn')->relationship('staff', 'name')->disabled(),
                    Forms\Components\Select::make('customer_id')->label('Khách hàng')->relationship('customer', 'name')->disabled(),
                    Forms\Components\Placeholder::make('created')
                        ->label('Tạo lúc')
                        ->content(fn (?Order $record) => $record?->created_at?->format('H:i d/m/Y')),
                ]),
            Forms\Components\Section::make('Xử lý')
                ->columns(2)
                ->schema([
                    Forms\Components\Select::make('status')
                        ->label('Trạng thái bếp / phục vụ')
                        ->options(OrderStatus::class)
                        ->required(),
                    Forms\Components\Select::make('payment_status')
                        ->label('Thanh toán')
                        ->options(PaymentStatus::class)
                        ->required(),
                    Forms\Components\Textarea::make('note')->label('Ghi chú')->rows(2)->columnSpanFull(),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with(['table', 'customer', 'staff']))
            ->columns([
                Tables\Columns\TextColumn::make('code')
                    ->label('Mã đơn')
                    ->searchable()
                    ->weight('bold'),
                Tables\Columns\TextColumn::make('table.number')
                    ->label('Bàn')
                    ->placeholder('Mang đi')
                    ->sortable(),
                Tables\Columns\TextColumn::make('customer.name')
                    ->label('Khách')
                    ->placeholder('—')
                    ->toggleable(),
                Tables\Columns\TextColumn::make('staff.name')
                    ->label('Nhân viên')
                    ->placeholder('—')
                    ->toggleable(isToggledHiddenByDefault: true),
                Tables\Columns\TextColumn::make('status')
                    ->label('Trạng thái')
                    ->badge()
                    ->sortable(),
                Tables\Columns\TextColumn::make('payment_status')
                    ->label('Thanh toán')
                    ->badge()
                    ->sortable(),
                Tables\Columns\TextColumn::make('total_amount')
                    ->label('Tổng tiền')
                    ->money('VND')
                    ->sortable(),
                Tables\Columns\TextColumn::make('created_at')
                    ->label('Tạo lúc')
                    ->dateTime('H:i d/m/Y')
                    ->description(fn (Order $record) => $record->created_at->diffForHumans())
                    ->sortable(),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('status')
                    ->label('Trạng thái')
                    ->options(OrderStatus::class)
                    ->multiple(),
                Tables\Filters\SelectFilter::make('payment_status')
                    ->label('Thanh toán')
                    ->options(PaymentStatus::class),
                Tables\Filters\Filter::make('today')
                    ->label('Hôm nay')
                    ->query(fn ($query) => $query->whereDate('created_at', today())),
            ])
            ->actions([
                self::statusAction('preparing', 'Bếp nhận', 'heroicon-o-fire', 'warning', [OrderStatus::Placed], OrderStatus::Preparing),
                self::statusAction('serving', 'Ra món', 'heroicon-o-truck', 'info', [OrderStatus::Preparing], OrderStatus::Serving),
                self::statusAction('completed', 'Hoàn thành', 'heroicon-o-check-circle', 'success', [OrderStatus::Serving], OrderStatus::Completed),
                self::statusAction('cancelled', 'Hủy đơn', 'heroicon-o-x-circle', 'danger', [OrderStatus::Placed, OrderStatus::Preparing, OrderStatus::Serving], OrderStatus::Cancelled, confirm: true),
                Tables\Actions\EditAction::make()->label('Chi tiết')->icon('heroicon-o-eye'),
            ])
            ->defaultSort('created_at', 'desc')
            ->poll('15s');
    }

    /**
     * Nút đổi trạng thái nhanh, chỉ hiện khi đơn đang ở một trong các trạng thái $from.
     *
     * @param  array<int, OrderStatus>  $from
     */
    private static function statusAction(string $name, string $label, string $icon, string $color, array $from, OrderStatus $to, bool $confirm = false): Tables\Actions\Action
    {
        return Tables\Actions\Action::make($name)
            ->label($label)
            ->icon($icon)
            ->color($color)
            ->visible(fn (Order $record) => in_array($record->status, $from, true))
            ->requiresConfirmation($confirm)
            ->action(function (Order $record) use ($to) {
                $record->update(['status' => $to]);
                $record->releaseTableIfDone();

                Notification::make()
                    ->title("Đơn {$record->code}: {$to->getLabel()}")
                    ->success()
                    ->send();
            });
    }

    public static function getRelations(): array
    {
        return [
            ItemsRelationManager::class,
        ];
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListOrders::route('/'),
            'edit' => Pages\EditOrder::route('/{record}/edit'),
        ];
    }
}
