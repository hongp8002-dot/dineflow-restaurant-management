<?php

namespace App\Filament\Resources\CategoryResource\Pages;

use App\Filament\Resources\CategoryResource;
use App\Models\Category;
use Filament\Actions;
use Filament\Resources\Pages\ManageRecords;

/** Thêm / sửa danh mục ngay trên một trang (hộp thoại), không cần trang riêng. */
class ManageCategories extends ManageRecords
{
    protected static string $resource = CategoryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make()
                // Giống API: không nhập thứ tự thì xếp cuối danh sách
                ->mutateFormDataUsing(function (array $data): array {
                    $data['sort_order'] ??= (int) Category::max('sort_order') + 1;

                    return $data;
                }),
        ];
    }
}
