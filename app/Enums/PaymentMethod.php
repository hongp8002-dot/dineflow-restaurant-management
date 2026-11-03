<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

/**
 * Khớp enum PaymentMethod { cash, qr, card } bên Flutter.
 * ('qr' = chuyển khoản qua mã QR)
 */
enum PaymentMethod: string implements HasLabel
{
    case Cash = 'cash';
    case Qr = 'qr';
    case Card = 'card';

    public function getLabel(): string
    {
        return match ($this) {
            self::Cash => 'Tiền mặt',
            self::Qr => 'QR / Chuyển khoản',
            self::Card => 'Thẻ ngân hàng',
        };
    }
}
