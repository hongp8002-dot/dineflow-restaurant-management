<?php

namespace App\Filament\Resources\ReservationResource\Pages;

use App\Filament\Resources\ReservationResource;
use App\Models\Reservation;
use Filament\Resources\Pages\ListRecords;

class ListReservations extends ListRecords
{
    protected static string $resource = ReservationResource::class;

    public function mount(): void
    {
        // Giống API GET /reservations: dọn lượt giữ quá hạn và khách không đến trước khi hiện
        Reservation::expireStale();

        parent::mount();
    }
}
