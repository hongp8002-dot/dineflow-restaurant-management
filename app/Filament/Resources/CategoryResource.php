<?php

namespace App\Filament\Resources;

use App\Filament\Resources\CategoryResource\Pages;
use App\Models\Category;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

/**
 * Danh mục món trên web /admin — cùng chức năng và quy tắc với tab Danh mục ở màn Thực đơn của app Admin
 * (API /api/admin/categories): tên không trùng, còn món thì không xóa được (Category::deletionBlockedReason).
 */
class CategoryResource extends Resource
{
    protected static ?string $model = Category::class;

    protected static ?string $navigationIcon = 'heroicon-o-tag';

    protected static ?string $navigationGroup = 'Thực đơn';

    protected static ?string $modelLabel = 'danh mục';

    protected static ?string $pluralModelLabel = 'Danh mục';

    protected static ?int $navigationSort = 0;

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\TextInput::make('name')
                ->label('Tên danh mục')
                ->required()
                ->maxLength(100)
                ->unique(ignoreRecord: true),
            Forms\Components\TextInput::make('icon')
                ->label('Biểu tượng')
                ->helperText('Tên Material icon, ví dụ: coffee, rice_bowl, local_bar')
                ->maxLength(50),
            Forms\Components\TextInput::make('sort_order')
                ->label('Thứ tự hiển thị')
                ->numeric()
                ->minValue(0)
                // Cột sort_order không được rỗng: khi sửa phải có giá trị; khi thêm mới để trống = xếp cuối
                ->required(fn (string $operation): bool => $operation === 'edit')
                ->helperText('Để trống khi thêm mới: tự xếp cuối danh sách'),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('sort_order')
                    ->label('Thứ tự')
                    ->sortable(),
                Tables\Columns\TextColumn::make('name')
                    ->label('Tên danh mục')
                    ->searchable()
                    ->sortable(),
                Tables\Columns\TextColumn::make('icon')
                    ->label('Biểu tượng')
                    ->placeholder('—'),
                Tables\Columns\TextColumn::make('foods_count')
                    ->label('Số món')
                    ->counts('foods')
                    ->badge(),
            ])
            ->defaultSort('sort_order')
            ->actions([
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make()
                    // Cùng quy tắc với API: còn món thì không cho xóa
                    ->before(function (Tables\Actions\DeleteAction $action, Category $record) {
                        if ($reason = $record->deletionBlockedReason()) {
                            Notification::make()->danger()->title('Không xóa được')->body($reason)->send();
                            $action->cancel();
                        }
                    }),
            ]);
        // Không có xóa hàng loạt: mỗi lần xóa phải qua kiểm tra "còn món" ở trên.
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ManageCategories::route('/'),
        ];
    }
}
