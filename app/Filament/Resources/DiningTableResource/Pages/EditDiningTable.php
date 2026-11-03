<?php

namespace App\Filament\Resources\DiningTableResource\Pages;

use App\Filament\Resources\DiningTableResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditDiningTable extends EditRecord
{
    protected static string $resource = DiningTableResource::class;

    protected function getHeaderActions(): array
    {
        return [Actions\DeleteAction::make()];
    }
}
