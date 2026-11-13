<?php

namespace App\Filament\Resources\FoodResource\Pages;

use App\Filament\Resources\FoodResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditFood extends EditRecord
{
    protected static string $resource = FoodResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make()
                ->before(function (Actions\DeleteAction $action) {
                    // Cùng quy tắc với app Admin (DELETE /api/admin/foods/{id})
                    if ($reason = $this->record->deletionBlockedReason()) {
                        \Filament\Notifications\Notification::make()->title($reason)->danger()->send();
                        $action->cancel();
                    }
                }),
        ];
    }
}
