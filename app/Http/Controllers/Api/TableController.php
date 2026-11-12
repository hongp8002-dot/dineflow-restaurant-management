<?php

namespace App\Http\Controllers\Api;

use App\Enums\TableStatus;
use App\Http\Resources\TableResource;
use App\Models\DiningTable;
use App\Models\Reservation;
use Carbon\Carbon;
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

    /**
     * GET /api/tables/available?datetime=2026-11-13T19:00:00
     *
     * Trả về tất cả bàn kèm field `available: true/false` cho thời điểm đặt bàn cụ thể.
     * Bàn bị coi là "không trống" nếu:
     *  - Đang phục vụ hoặc bị khoá ngay lúc này, HOẶC
     *  - Có lượt đặt bàn trong khoảng (datetime - 90 phút, datetime + 90 phút).
     *
     * Dùng bởi màn hình Đặt bàn của khách: sau khi chọn ngày/giờ, app gọi API này
     * để hiển thị bàn trống THẬT SỰ theo thời điểm đó, không phải trạng thái hiện tại.
     */
    public function available(Request $request): JsonResponse
    {
        $request->validate([
            'datetime' => ['required', 'date'],
        ]);

        // Dọn các lượt giữ bàn đã quá hạn trước khi kiểm tra xung đột.
        Reservation::expireLapsedHolds();

        // Đổi về múi giờ của quán giống ReservationController::store(), nếu không giờ UTC
        // và giờ địa phương bị so lệch 7 tiếng → bàn hiện "Trống" nhưng đặt lại bị từ chối.
        $dt          = Carbon::parse($request->input('datetime'))->setTimezone(config('app.timezone'));
        $windowStart = $dt->copy()->subMinutes(90);
        $windowEnd   = $dt->copy()->addMinutes(90);

        // Các bàn đã có người đặt trong cửa sổ 90 phút quanh thời điểm khách chọn.
        $bookedIds = Reservation::blocking()
            ->whereBetween('date_time', [$windowStart, $windowEnd])
            ->get()
            ->flatMap(fn (Reservation $r) => $r->table_ids)
            ->unique()
            ->values()
            ->all();

        $tables = DiningTable::orderBy('id')
            ->get()
            ->map(function (DiningTable $table) use ($bookedIds) {
                // Bàn có available = true khi: đang hoạt động, không bị khoá,
                // không phải đang phục vụ ngay bây giờ, và không có ai đặt trước.
                $available = $table->is_active
                    && !$table->is_locked
                    && $table->isEmpty()
                    && !in_array($table->id, $bookedIds);

                return array_merge(
                    (new TableResource($table))->resolve(),
                    ['available' => $available],
                );
            })
            ->values();

        return $this->ok($tables, 'Thành công', 200, [
            'areas'    => DiningTable::query()->groupBy('area')->orderByRaw('MIN(id)')->pluck('area'),
            'datetime' => $dt->toIso8601String(),
        ]);
    }
}
