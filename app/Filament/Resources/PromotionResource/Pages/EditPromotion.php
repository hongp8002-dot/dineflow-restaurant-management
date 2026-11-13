<?php

namespace App\Filament\Resources\PromotionResource\Pages;

use App\Filament\Resources\PromotionResource;
use Filament\Resources\Pages\EditRecord;

class EditPromotion extends EditRecord
{
    protected static string $resource = PromotionResource::class;

    // Không có nút Xóa (giống app và API): voucher đã dùng trong hóa đơn cũ phải được giữ.
    // Muốn ngừng khuyến mãi thì tắt "Kích hoạt".
}
