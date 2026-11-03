<?php

namespace App\Enums;

use Filament\Support\Contracts\HasColor;
use Filament\Support\Contracts\HasLabel;

enum OrderStatus: string implements HasLabel, HasColor
{
    case Placed = 'placed';
    case Preparing = 'preparing';
    case Serving = 'serving';
    case Completed = 'completed';
    case Cancelled = 'cancelled';

    public function getLabel(): string
    {
        return match ($this) {
            self::Placed => 'Đã đặt',
            self::Preparing => 'Đang chuẩn bị',
            self::Serving => 'Đang phục vụ',
            self::Completed => 'Hoàn thành',
            self::Cancelled => 'Đã hủy',
        };
    }

    public function getColor(): string
    {
        return match ($this) {
            self::Placed => 'gray',
            self::Preparing => 'warning',
            self::Serving => 'info',
            self::Completed => 'success',
            self::Cancelled => 'danger',
        };
    }

    /** Đơn còn đang mở (chưa hoàn thành / chưa hủy). */
    public function isOpen(): bool
    {
        return in_array($this, [self::Placed, self::Preparing, self::Serving], true);
    }

    /**
     * Đơn chỉ đi tiến theo chuỗi placed → preparing → serving → completed (được bỏ qua bước),
     * và chỉ hủy được khi đơn còn đang mở. Đơn đã hoàn thành / đã hủy thì khóa.
     */
    public function canTransitionTo(self $to): bool
    {
        if (! $this->isOpen()) {
            return false;
        }

        if ($to === self::Cancelled) {
            return true;
        }

        $flow = [self::Placed, self::Preparing, self::Serving, self::Completed];

        return array_search($to, $flow, true) > array_search($this, $flow, true);
    }
}
