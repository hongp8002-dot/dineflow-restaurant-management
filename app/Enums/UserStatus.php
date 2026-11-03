<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

enum UserStatus: string implements HasLabel, HasColor
{
    case Active = 'active';
    case Locked = 'locked';

    public function getLabel(): string
    {
        return match ($this) {
            self::Active => 'Hoạt động',
            self::Locked => 'Đã khóa',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Active => 'success',
            self::Locked => 'danger',
        };
    }
}
