<?php

namespace App\Filament\Resources\DiningTableResource\Pages;

use App\Filament\Resources\DiningTableResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListDiningTables extends ListRecords
{
    protected static string $resource = DiningTableResource::class;

    protected function getHeaderActions(): array
    {
        return [Actions\CreateAction::make()];
    }
}
