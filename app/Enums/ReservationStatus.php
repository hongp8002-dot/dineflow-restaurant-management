<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

enum ReservationStatus: string implements HasLabel, HasColor
{
    case Upcoming = 'upcoming';
    case Completed = 'completed';
    case Cancelled = 'cancelled';

    public function getLabel(): string
    {
        return match ($this) {
            self::Upcoming => 'Sắp tới',
            self::Completed => 'Đã hoàn thành',
            self::Cancelled => 'Đã hủy',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Upcoming => 'info',
            self::Completed => 'success',
            self::Cancelled => 'danger',
        };
    }
}
