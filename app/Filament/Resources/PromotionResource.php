<?php

namespace App\Filament\Resources;

use App\Filament\Resources\PromotionResource\Pages;
use App\Models\Promotion;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class PromotionResource extends Resource
{
    protected static ?string $model = Promotion::class;

    protected static ?string $navigationIcon = 'heroicon-o-ticket';

    protected static ?string $navigationGroup = 'Thực đơn';

    protected static ?string $modelLabel = 'khuyến mãi';

    protected static ?string $pluralModelLabel = 'Khuyến mãi';

    protected static ?int $navigationSort = 2;

    protected static ?string $recordTitleAttribute = 'title';

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('Voucher')
                ->columns(2)
                ->schema([
                    Forms\Components\TextInput::make('code')
                        ->label('Mã voucher')
                        ->required()
                        ->unique(ignoreRecord: true)
                        ->maxLength(30)
                        ->extraInputAttributes(['style' => 'text-transform: uppercase'])
                        ->dehydrateStateUsing(fn (?string $state) => strtoupper(trim((string) $state))),
                    Forms\Components\TextInput::make('title')->label('Tên chương trình')->required()->maxLength(255),
                    Forms\Components\Textarea::make('description')->label('Mô tả')->rows(2)->columnSpanFull(),
                ]),
            Forms\Components\Section::make('Mức giảm')
                ->columns(3)
                ->schema([
                    Forms\Components\TextInput::make('discount_percent')
                        ->label('Giảm')
                        ->numeric()->minValue(1)->maxValue(100)->suffix('%')->required(),
                    Forms\Components\TextInput::make('max_discount')
                        ->label('Giảm tối đa')
                        ->numeric()->minValue(0)->suffix('₫')
                        ->helperText('Để trống = không giới hạn'),
                    Forms\Components\TextInput::make('min_order_amount')
                        ->label('Đơn tối thiểu')
                        ->numeric()->minValue(0)->default(0)->suffix('₫')->required(),
                ]),
            Forms\Components\Section::make('Thời gian áp dụng')
                ->columns(3)
                ->schema([
                    Forms\Components\DateTimePicker::make('valid_from')->label('Từ ngày')->seconds(false)->required(),
                    Forms\Components\DateTimePicker::make('valid_to')->label('Đến ngày')->seconds(false)->required()->after('valid_from'),
                    Forms\Components\Toggle::make('is_active')->label('Kích hoạt')->default(true)->inline(false),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('code')->label('Mã')->searchable()->weight('bold')->copyable(),
                Tables\Columns\TextColumn::make('title')->label('Chương trình')->searchable(),
                Tables\Columns\TextColumn::make('discount_percent')->label('Giảm')->suffix('%')->sortable(),
                Tables\Columns\TextColumn::make('max_discount')->label('Tối đa')->money('VND')->placeholder('Không giới hạn'),
                Tables\Columns\TextColumn::make('min_order_amount')->label('Đơn tối thiểu')->money('VND'),
                Tables\Columns\TextColumn::make('valid_from')->label('Từ')->dateTime('d/m/Y')->sortable(),
                Tables\Columns\TextColumn::make('valid_to')->label('Đến')->dateTime('d/m/Y')->sortable(),
                Tables\Columns\TextColumn::make('display_status')
                    ->label('Tình trạng')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'active' => 'Đang áp dụng',
                        'upcoming' => 'Sắp diễn ra',
                        default => 'Đã hết hạn',
                    })
                    ->color(fn (string $state) => match ($state) {
                        'active' => 'success',
                        'upcoming' => 'info',
                        default => 'gray',
                    }),
                Tables\Columns\ToggleColumn::make('is_active')->label('Kích hoạt'),
            ])
            ->filters([
                Tables\Filters\TernaryFilter::make('is_active')->label('Kích hoạt'),
                Tables\Filters\Filter::make('valid')
                    ->label('Đang hiệu lực')
                    ->query(fn ($query) => $query->valid()),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                // Không xóa (giống app / PromotionAdminController): hóa đơn cũ còn tham chiếu voucher.
            ])
            ->defaultSort('valid_from', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListPromotions::route('/'),
            'create' => Pages\CreatePromotion::route('/create'),
            'edit' => Pages\EditPromotion::route('/{record}/edit'),
        ];
    }
}
