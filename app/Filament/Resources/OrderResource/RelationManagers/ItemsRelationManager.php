<?php

namespace App\Filament\Resources\OrderResource\RelationManagers;

use App\Models\OrderItem;
use Filament\Resources\RelationManagers\RelationManager;
use Filament\Tables;
use Filament\Tables\Table;

/** Danh sách món trong đơn (chỉ xem, để tổng tiền luôn khớp với các dòng món). */
class ItemsRelationManager extends RelationManager
{
    protected static string $relationship = 'items';

    protected static ?string $title = 'Món trong đơn';

    public function isReadOnly(): bool
    {
        return true;
    }

    public function table(Table $table): Table
    {
        return $table
            ->recordTitleAttribute('food_name')
            ->columns([
                Tables\Columns\TextColumn::make('food_name')->label('Món')->weight('bold'),
                Tables\Columns\TextColumn::make('quantity')->label('SL')->alignCenter(),
                Tables\Columns\TextColumn::make('options')
                    ->label('Tùy chọn')
                    ->state(fn (OrderItem $record) => collect($record->options)->pluck('name')->join(', ') ?: '—'),
                Tables\Columns\TextColumn::make('price')->label('Đơn giá')->money('VND'),
                Tables\Columns\TextColumn::make('line_total')->label('Thành tiền')->money('VND'),
                Tables\Columns\TextColumn::make('note')->label('Ghi chú')->placeholder('—')->wrap(),
            ])
            ->paginated(false);
    }
}
