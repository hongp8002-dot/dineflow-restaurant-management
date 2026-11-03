<?php

namespace App\Filament\Resources\OrderResource\Pages;

use App\Filament\Resources\OrderResource;
use Filament\Resources\Pages\EditRecord;

class EditOrder extends EditRecord
{
    protected static string $resource = OrderResource::class;

    protected static ?string $title = 'Chi tiết đơn hàng';

    /** Đổi sang hủy / hoàn thành (đã trả tiền) thì trả bàn về trống. */
    protected function afterSave(): void
    {
        $this->record->releaseTableIfDone();
    }
}
