<?php

namespace App\Filament\Resources;

use App\Enums\FoodOptionGroup;
use App\Filament\Resources\FoodResource\Pages;
use App\Models\Food;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class FoodResource extends Resource
{
    protected static ?string $model = Food::class;

    protected static ?string $navigationIcon = 'heroicon-o-cake';

    protected static ?string $navigationGroup = 'Thực đơn';

    protected static ?string $modelLabel = 'món ăn';

    protected static ?string $pluralModelLabel = 'Món ăn';

    protected static ?int $navigationSort = 1;

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('Thông tin món')
                ->columns(2)
                ->schema([
                    Forms\Components\TextInput::make('name')
                        ->label('Tên món')
                        ->required()
                        ->maxLength(255),
                    Forms\Components\Select::make('category_id')
                        ->label('Danh mục')
                        ->relationship('category', 'name')
                        ->searchable()
                        ->preload()
                        ->required()
                        ->createOptionForm([
                            Forms\Components\TextInput::make('name')->label('Tên danh mục')->required()->unique('categories', 'name'),
                            Forms\Components\TextInput::make('icon')->label('Icon (tên Material icon)')->placeholder('coffee'),
                        ]),
                    Forms\Components\TextInput::make('price')
                        ->label('Giá')
                        ->numeric()
                        ->minValue(0)
                        ->suffix('₫')
                        ->required(),
                    Forms\Components\TextInput::make('rating')
                        ->label('Đánh giá')
                        ->numeric()
                        ->minValue(0)
                        ->maxValue(5)
                        ->step(0.1)
                        ->default(4.5),
                    Forms\Components\Textarea::make('description')
                        ->label('Mô tả')
                        ->rows(3)
                        ->columnSpanFull(),
                    Forms\Components\Toggle::make('is_available')
                        ->label('Đang bán')
                        ->default(true),
                    Forms\Components\Toggle::make('is_best_seller')
                        ->label('Bán chạy'),
                ]),

            Forms\Components\Section::make('Hiển thị trên app')
                ->columns(3)
                ->schema([
                    Forms\Components\FileUpload::make('image')
                        ->label('Ảnh món')
                        ->image()
                        ->imageEditor()
                        ->disk('public')
                        ->directory('foods')
                        ->visibility('public')
                        ->maxSize(4096)
                        ->columnSpanFull(),
                    Forms\Components\TextInput::make('icon')
                        ->label('Icon dự phòng')
                        ->helperText('Hiện khi món không có ảnh. Vd: coffee, rice_bowl'),
                    Forms\Components\ColorPicker::make('color')
                        ->label('Màu nền'),
                ]),

            Forms\Components\Section::make('Tùy chọn (size, topping)')
                ->schema([
                    Forms\Components\Repeater::make('options')
                        ->label('')
                        ->relationship()
                        ->schema([
                            Forms\Components\TextInput::make('name')->label('Tên')->required(),
                            Forms\Components\Select::make('group')
                                ->label('Nhóm')
                                ->options(FoodOptionGroup::class)
                                ->required(),
                            Forms\Components\TextInput::make('price_modifier')
                                ->label('Phụ thu')
                                ->numeric()
                                ->default(0)
                                ->suffix('₫')
                                ->required(),
                        ])
                        ->columns(3)
                        ->defaultItems(0)
                        ->addActionLabel('Thêm tùy chọn')
                        ->collapsible()
                        ->itemLabel(fn (array $state): ?string => $state['name'] ?? null),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\ImageColumn::make('image')
                    ->label('Ảnh')
                    ->disk('public')
                    ->square(),
                Tables\Columns\TextColumn::make('name')
                    ->label('Tên món')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('category.name')
                    ->label('Danh mục')
                    ->badge()
                    ->sortable(),
                Tables\Columns\TextColumn::make('price')
                    ->label('Giá')
                    ->money('VND')
                    ->sortable(),
                Tables\Columns\TextColumn::make('rating')
                    ->label('Đánh giá')
                    ->icon('heroicon-s-star')
                    ->iconColor('warning')
                    ->sortable(),
                Tables\Columns\IconColumn::make('is_best_seller')
                    ->label('Bán chạy')
                    ->boolean(),
                Tables\Columns\ToggleColumn::make('is_available')
                    ->label('Đang bán'),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('category_id')
                    ->label('Danh mục')
                    ->relationship('category', 'name')
                    ->preload(),
                Tables\Filters\TernaryFilter::make('is_available')
                    ->label('Đang bán'),
                Tables\Filters\TernaryFilter::make('is_best_seller')
                    ->label('Bán chạy'),
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make(),
            ])
            ->bulkActions([
                Tables\Actions\BulkActionGroup::make([
                    Tables\Actions\DeleteBulkAction::make(),
                ]),
            ])
            ->defaultSort('category_id');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListFoods::route('/'),
            'create' => Pages\CreateFood::route('/create'),
            'edit' => Pages\EditFood::route('/{record}/edit'),
        ];
    }
}
