<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

enum TableStatus: string implements HasLabel, HasColor
{
    case Empty = 'empty';
    case Serving = 'serving';
    case Reserved = 'reserved';

    public function getLabel(): string
    {
        return match ($this) {
            self::Empty => 'Trống',
            self::Serving => 'Đang phục vụ',
            self::Reserved => 'Đã đặt trước',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Empty => 'success',
            self::Serving => 'warning',
            self::Reserved => 'info',
        };
    }
}
