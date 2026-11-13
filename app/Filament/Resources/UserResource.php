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

    /** Mật khẩu mặc định khi Admin tạo tài khoản nhân viên — giống POST /api/admin/users của app. */
    public const DEFAULT_PASSWORD = User::DEFAULT_PASSWORD;

    /** Vai trò Admin được tạo / đổi qua: chỉ nhân viên (giống app). Khách tự đăng ký trên app. */
    private static function staffRoleOptions(): array
    {
        return [
            UserRole::OrderStaff->value => UserRole::OrderStaff->getLabel(),
            UserRole::Cashier->value => UserRole::Cashier->getLabel(),
        ];
    }

    /** Tài khoản đang sửa là nhân viên (đổi vai trò được) hay Admin / Khách (chỉ xem vai trò). */
    private static function isStaffAccount(?User $record): bool
    {
        return $record === null || in_array($record->role, [UserRole::OrderStaff, UserRole::Cashier], true);
    }

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
                    // Không có ô mật khẩu (giống app): tạo mới dùng mật khẩu mặc định, người dùng tự đổi trong app.
                    Forms\Components\Placeholder::make('default_password')
                        ->label('Mật khẩu')
                        ->content('Mặc định '.self::DEFAULT_PASSWORD.' — nhân viên tự đổi sau khi đăng nhập app.')
                        ->visibleOn('create'),
                    Forms\Components\TextInput::make('avatar_url')->label('Ảnh đại diện (URL)')->url()->columnSpanFull(),
                ]),
            Forms\Components\Section::make('Phân quyền')
                ->columns(2)
                ->schema([
                    // Giống app: chỉ tạo / đổi qua lại NV Order và Thu ngân. Tài khoản Admin, Khách hàng
                    // hiện vai trò nhưng không đổi được (ô bị khóa nên không được lưu).
                    Forms\Components\Select::make('role')
                        ->label('Vai trò')
                        ->options(fn (?User $record): array => self::isStaffAccount($record)
                            ? self::staffRoleOptions()
                            : [$record->role->value => $record->role->getLabel()])
                        ->default(UserRole::OrderStaff->value)
                        ->disabled(fn (?User $record): bool => ! self::isStaffAccount($record))
                        ->rule(
                            \Illuminate\Validation\Rule::in(array_keys(self::staffRoleOptions())),
                            fn (?User $record): bool => self::isStaffAccount($record),
                        )
                        ->required(),
                    Forms\Components\Select::make('status')
                        ->label('Trạng thái')
                        ->options(UserStatus::class)
                        ->required()
                        ->visibleOn('edit'),
                    // Mã thành viên tự sinh khi khách đăng ký; điểm chỉ cộng khi thanh toán → chỉ xem
                    Forms\Components\TextInput::make('member_code')
                        ->label('Mã thành viên')
                        ->disabled()
                        ->visible(fn (?User $record): bool => $record?->role === UserRole::Customer),
                    Forms\Components\TextInput::make('points')
                        ->label('Điểm tích lũy')
                        ->disabled()
                        ->visible(fn (?User $record): bool => $record?->role === UserRole::Customer),
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
                // Đặt lại mật khẩu nhân viên về 123456 (cùng logic API app: User::resetToDefaultPassword)
                Tables\Actions\Action::make('resetPassword')
                    ->label('Đặt lại mật khẩu')
                    ->icon('heroicon-o-key')
                    ->color('warning')
                    ->visible(fn (User $record) => in_array($record->role, [UserRole::OrderStaff, UserRole::Cashier], true))
                    ->requiresConfirmation()
                    ->modalHeading(fn (User $record) => "Đặt lại mật khẩu cho {$record->name}?")
                    ->modalDescription('Mật khẩu sẽ về '.User::DEFAULT_PASSWORD.' và nhân viên bị đăng xuất khỏi mọi thiết bị. Mật khẩu cũ không xem được (lưu dạng băm).')
                    ->action(function (User $record) {
                        $record->resetToDefaultPassword();
                        Notification::make()->title("Đã đặt lại mật khẩu của {$record->name} về ".User::DEFAULT_PASSWORD)->success()->send();
                    }),
                Tables\Actions\EditAction::make(),
                // Không xóa tài khoản (giống app): người đã có đơn / hóa đơn chỉ được khóa để giữ báo cáo.
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
