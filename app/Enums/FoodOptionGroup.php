<?php

namespace App\Enums;

use Filament\Support\Contracts\HasLabel;

/** Khớp enum FoodOptionType { size, topping } bên Flutter. */
enum FoodOptionGroup: string implements HasLabel
{
    case Size = 'size';
    case Topping = 'topping';

    public function getLabel(): string
    {
        return match ($this) {
            self::Size => 'Kích cỡ',
            self::Topping => 'Topping',
        };
    }
}
