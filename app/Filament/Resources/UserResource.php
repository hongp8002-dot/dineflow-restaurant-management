<?php

namespace App\Filament\Resources;

use App\Enums\UserRole;
use App\Enums\UserStatus;
use App\Filament\Resources\UserResource\Pages;
use App\Models\User;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static ?string $navigationIcon = 'heroicon-o-users';

    protected static ?string $navigationGroup = 'Hệ thống';

    protected static ?string $modelLabel = 'tài khoản';

    protected static ?string $pluralModelLabel = 'Tài khoản';

    protected static ?int $navigationSort = 1;

    protected static ?string $recordTitleAttribute = 'name';

    public static function form(Form $form): Form
    {
        return $form->schema([
            Forms\Components\Section::make('Thông tin')
                ->columns(2)
                ->schema([
                    Forms\Components\TextInput::make('name')->label('Họ tên')->required()->maxLength(255),
                    Forms\Components\TextInput::make('email')->label('Email')->email()->required()->unique(ignoreRecord: true),
                    Forms\Components\TextInput::make('phone')->label('Số điện thoại')->tel()->unique(ignoreRecord: true)->maxLength(20),
                    Forms\Components\TextInput::make('password')
                        ->label('Mật khẩu')
                        ->password()
                        ->revealable()
                        ->minLength(6)
                        ->required(fn (string $operation) => $operation === 'create')
                        ->dehydrated(fn (?string $state) => filled($state)) // model đã tự hash qua cast 'hashed'
                        ->helperText(fn (string $operation) => $operation === 'edit' ? 'Để trống nếu không đổi mật khẩu.' : null),
                    Forms\Components\TextInput::make('avatar_url')->label('Ảnh đại diện (URL)')->url()->columnSpanFull(),
                ]),
            Forms\Components\Section::make('Phân quyền')
                ->columns(2)
                ->schema([
                    Forms\Components\Select::make('role')
                        ->label('Vai trò')
                        ->options(UserRole::class)
                        ->default(UserRole::Customer)
                        ->required(),
                    Forms\Components\Select::make('status')
                        ->label('Trạng thái')
                        ->options(UserStatus::class)
                        ->default(UserStatus::Active)
                        ->required(),
                    Forms\Components\TextInput::make('member_code')->label('Mã thành viên')->unique(ignoreRecord: true),
                    Forms\Components\TextInput::make('points')->label('Điểm tích lũy')->numeric()->minValue(0)->default(0),
                ]),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('name')->label('Họ tên')->searchable()->sortable()->weight('bold'),
                Tables\Columns\TextColumn::make('email')->label('Email')->searchable()->copyable(),
                Tables\Columns\TextColumn::make('phone')->label('SĐT')->searchable()->placeholder('—'),
                Tables\Columns\TextColumn::make('role')->label('Vai trò')->badge()->sortable(),
                Tables\Columns\TextColumn::make('status')->label('Trạng thái')->badge()->sortable(),
                Tables\Columns\TextColumn::make('created_at')->label('Ngày tạo')->dateTime('d/m/Y')->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                Tables\Filters\SelectFilter::make('role')->label('Vai trò')->options(UserRole::class),
                Tables\Filters\SelectFilter::make('status')->label('Trạng thái')->options(UserStatus::class),
            ])
            ->actions([
                Tables\Actions\Action::make('toggleLock')
                    ->label(fn (User $record) => $record->isActive() ? 'Khóa' : 'Mở khóa')
                    ->icon(fn (User $record) => $record->isActive() ? 'heroicon-o-lock-closed' : 'heroicon-o-lock-open')
                    ->color(fn (User $record) => $record->isActive() ? 'danger' : 'success')
                    ->visible(fn (User $record) => $record->id !== auth()->id()) // không tự khóa mình
                    ->requiresConfirmation()
                    ->modalHeading(fn (User $record) => $record->isActive() ? "Khóa tài khoản {$record->name}?" : "Mở khóa tài khoản {$record->name}?")
                    ->action(function (User $record) {
                        $lock = $record->isActive();
                        $record->update(['status' => $lock ? UserStatus::Locked : UserStatus::Active]);

                        // Khóa thì thu hồi toàn bộ token để app bị đăng xuất ngay
                        if ($lock) {
                            $record->tokens()->delete();
                        }

                        Notification::make()
                            ->title($lock ? 'Đã khóa tài khoản' : 'Đã mở khóa tài khoản')
                            ->success()
                            ->send();
                    }),
                Tables\Actions\EditAction::make(),
                Tables\Actions\DeleteAction::make()
                    ->visible(fn (User $record) => $record->id !== auth()->id()),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListUsers::route('/'),
            'create' => Pages\CreateUser::route('/create'),
            'edit' => Pages\EditUser::route('/{record}/edit'),
        ];
    }
}
