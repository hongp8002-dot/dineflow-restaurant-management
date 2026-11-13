<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

/** Lý do hủy đơn (nhóm chốt 13/11). Chọn "Khác" thì bắt buộc ghi chú. */
enum CancelReason: string implements HasLabel
{
    case WrongEntry = 'wrong_entry';
    case CustomerLeft = 'customer_left';
    case OutOfStock = 'out_of_stock';
    case Other = 'other';

    public function getLabel(): string
    {
        return match ($this) {
            self::WrongEntry => 'Nhập nhầm',
            self::CustomerLeft => 'Khách bỏ về',
            self::OutOfStock => 'Hết món',
            self::Other => 'Khác',
        };
    }
}
