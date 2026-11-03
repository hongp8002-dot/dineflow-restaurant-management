<?php

namespace App\Http\Controllers\Api;

use App\Enums\TableStatus;
use App\Http\Resources\TableResource;
use App\Models\DiningTable;
use App\Models\Reservation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class TableController extends ApiController
{
    /**
     * GET /api/tables?area=&status=
     *
     * Bàn đang trống nhưng có lượt đặt bắt đầu trong khoảng (-30 phút, +60 phút) quanh hiện tại
     * được báo là "reserved" (chỉ trong phản hồi, không đổi dữ liệu trong DB).
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'area' => ['nullable', 'string', 'max:50'],
            'status' => ['nullable', Rule::enum(TableStatus::class)],
        ]);

        $soon = [];
        Reservation::blocking()
            ->whereBetween('date_time', [now()->subMinutes(30), now()->addHour()])
            ->get()
            ->each(function (Reservation $r) use (&$soon) {
                foreach ($r->table_ids as $id) {
                    $soon[$id] = min($soon[$id] ?? $r->date_time, $r->date_time);
                }
            });

        // Theo thứ tự tạo bàn (không xếp chữ cái) để các khu vực giữ thứ tự quán đặt: Tầng 1, Tầng 2, Ngoài trời...
        $tables = DiningTable::inArea($request->input('area'))
            ->orderBy('id')
            ->get()
            ->each(function (DiningTable $table) use ($soon) {
                $at = $soon[$table->id] ?? null;
                $table->setAttribute('next_reservation_at', $at?->toIso8601String());
                $table->setAttribute('effective_status', ($table->isEmpty() && $at) ? TableStatus::Reserved->value : $table->status->value);
            })
            ->when($request->filled('status'), fn ($c) => $c->filter(fn ($t) => $t->effective_status === $request->input('status')))
            ->values();

        return $this->ok($this->items($tables, TableResource::class), 'Thành công', 200, [
            'areas' => DiningTable::query()->groupBy('area')->orderByRaw('MIN(id)')->pluck('area'),
        ]);
    }
}
