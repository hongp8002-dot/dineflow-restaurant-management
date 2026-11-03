<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Enums\UserStatus;
use App\Filament\Resources\UserResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditUser extends EditRecord
{
    protected static string $resource = UserResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make()->visible(fn () => $this->record->id !== auth()->id()),
        ];
    }

    /** Đổi trạng thái sang "khóa" từ form cũng phải thu hồi token. */
    protected function afterSave(): void
    {
        if ($this->record->status === UserStatus::Locked) {
            $this->record->tokens()->delete();
        }
    }
}
