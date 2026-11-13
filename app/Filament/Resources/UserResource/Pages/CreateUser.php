<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Enums\UserStatus;
use App\Filament\Resources\UserResource;
use Filament\Resources\Pages\CreateRecord;

class CreateUser extends CreateRecord
{
    protected static string $resource = UserResource::class;

    /** Giống POST /api/admin/users: mật khẩu mặc định, tài khoản hoạt động ngay. */
    protected function mutateFormDataBeforeCreate(array $data): array
    {
        $data['password'] = UserResource::DEFAULT_PASSWORD; // model tự mã hóa (cast 'hashed')
        $data['status'] = UserStatus::Active;

        return $data;
    }
}
