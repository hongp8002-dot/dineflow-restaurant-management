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
                    // Không chọn "Đã hủy" ở đây: hủy phải qua nút Hủy đơn (bắt buộc lý do).
                    // Đơn đã hủy thì khóa ô trạng thái.
                    Forms\Components\Select::make('status')
                        ->label('Trạng thái bếp / phục vụ')
                        ->options(fn (?Order $record) => $record?->status === OrderStatus::Cancelled
                            ? [OrderStatus::Cancelled->value => OrderStatus::Cancelled->getLabel()]
                            : collect(OrderStatus::cases())
                                ->reject(fn (OrderStatus $s) => $s === OrderStatus::Cancelled)
                                ->mapWithKeys(fn (OrderStatus $s) => [$s->value => $s->getLabel()])
                                ->all())
                        ->disabled(fn (?Order $record) => $record?->status === OrderStatus::Cancelled)
                        // Kiểm tra cả phía server: không lưu "Đã hủy" qua form (phải dùng nút Hủy đơn)
                        ->notIn([OrderStatus::Cancelled->value], fn (?Order $record) => $record?->status !== OrderStatus::Cancelled)
                        ->required(),
                    // Chỉ xem: thanh toán phải qua Thu ngân (tạo hóa đơn, gắn ca, cộng điểm)
                    Forms\Components\Select::make('payment_status')
                        ->label('Thanh toán')
                        ->options(PaymentStatus::class)
                        ->disabled(),
                    Forms\Components\Placeholder::make('cancel_info')
                        ->label('Thông tin hủy')
                        ->visible(fn (?Order $record) => $record?->status === OrderStatus::Cancelled)
                        ->content(fn (?Order $record) => $record?->cancel_reason
                            ? $record->cancel_reason->getLabel()
                                .($record->cancel_note ? ' — '.$record->cancel_note : '')
                                .' · '.($record->cancelledBy?->name ?? '?')
                                .' · '.$record->cancelled_at?->format('H:i d/m/Y')
                            : 'Hủy trước khi có chức năng ghi lý do')
                        ->columnSpanFull(),
                    Forms\Components\Textarea::make('note')->label('Ghi chú')->rows(2)->columnSpanFull(),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with(['table', 'customer', 'staff', 'cancelledBy']))
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
                // Đơn đã hủy: lý do · người hủy (nhóm chốt 13/11, cách A)
                Tables\Columns\TextColumn::make('cancel_reason')
                    ->label('Lý do hủy')
                    ->formatStateUsing(fn ($state, Order $record) => $state?->getLabel()
                        .($record->cancel_note ? ': '.$record->cancel_note : ''))
                    ->description(fn (Order $record) => $record->cancelledBy
                        ? $record->cancelledBy->name.' · '.$record->cancelled_at?->format('H:i d/m')
                        : null)
                    ->placeholder('—')
                    ->wrap()
                    ->toggleable(),
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
                Tables\Filters\SelectFilter::make('cancel_reason')
                    ->label('Lý do hủy')
                    ->options(\App\Enums\CancelReason::class),
                Tables\Filters\Filter::make('today')
                    ->label('Hôm nay')
                    ->query(fn ($query) => $query->whereDate('created_at', today())),
            ])
            ->actions([
                self::statusAction('preparing', 'Bếp nhận', 'heroicon-o-fire', 'warning', [OrderStatus::Placed], OrderStatus::Preparing),
                self::statusAction('serving', 'Ra món', 'heroicon-o-truck', 'info', [OrderStatus::Preparing], OrderStatus::Serving),
                self::statusAction('completed', 'Hoàn thành', 'heroicon-o-check-circle', 'success', [OrderStatus::Serving], OrderStatus::Completed),
                // Hủy đơn: bắt buộc lý do, cùng quy tắc với app (Order::cancelBy)
                Tables\Actions\Action::make('cancelled')
                    ->label('Hủy đơn')
                    ->icon('heroicon-o-x-circle')
                    ->color('danger')
                    ->visible(fn (Order $record) => $record->status->isOpen() && ! $record->isPaid())
                    ->modalHeading(fn (Order $record) => "Hủy đơn {$record->code}?")
                    ->form([
                        Forms\Components\Radio::make('reason')
                            ->label('Lý do hủy')
                            ->options(\App\Enums\CancelReason::class)
                            ->required()
                            ->live(),
                        Forms\Components\Textarea::make('note')
                            ->label('Ghi chú')
                            ->rows(2)
                            ->maxLength(255)
                            ->required(fn (Forms\Get $get) => $get('reason') === \App\Enums\CancelReason::Other->value),
                    ])
                    ->action(function (Order $record, array $data) {
                        $record->cancelBy(auth()->user(), \App\Enums\CancelReason::from($data['reason']), $data['note'] ?? null);
                        Notification::make()->title("Đã hủy đơn {$record->code}")->success()->send();
                    }),
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
                // Cùng quy tắc với API: đơn chưa có món thì chưa gửi bếp / ra món / hoàn thành
                if ($reason = $record->statusChangeBlockedReason($to)) {
                    Notification::make()->title($reason)->danger()->send();

                    return;
                }

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
