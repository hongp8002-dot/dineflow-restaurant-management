<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

enum UserRole: string implements HasLabel, HasColor
{
    case Admin = 'admin';
    case OrderStaff = 'order_staff';
    case Cashier = 'cashier';
    case Customer = 'customer';

    public function getLabel(): string
    {
        return match ($this) {
            self::Admin => 'Admin',
            self::OrderStaff => 'Nhân viên Order',
            self::Cashier => 'Thu ngân',
            self::Customer => 'Khách hàng',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Admin => 'danger',
            self::OrderStaff => 'info',
            self::Cashier => 'warning',
            self::Customer => 'gray',
        };
    }

    /** Nhân viên nội bộ (không phải khách hàng). */
    public function isStaff(): bool
    {
        return $this !== self::Customer;
    }
}
