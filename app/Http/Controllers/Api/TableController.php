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
     * Bàn đang trống nhưng có lượt đặt trong khoảng [bây giờ − 15 phút, bây giờ + 90 phút] được báo là
     * "reserved" (chỉ trong phản hồi, không đổi DB). Đúng bằng khoảng NV Order bị chặn mở bàn cho
     * khách vãng lai (DiningTable::heldReservation), nên sơ đồ bàn khớp với điều server cho phép.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'area' => ['nullable', 'string', 'max:50'],
            'status' => ['nullable', Rule::enum(TableStatus::class)],
        ]);

        Reservation::expireStale();

        // Lượt đặt sớm nhất đang giữ mỗi bàn (để NV Order / Thu ngân / Admin biết khách nào đặt)
        $soon = [];
        Reservation::blocking()
            ->with('customer')
            ->whereBetween('date_time', [
                now()->subMinutes(Reservation::GRACE_MINUTES),
                now()->addMinutes(Reservation::WINDOW_MINUTES),
            ])
            ->orderBy('date_time')
            ->get()
            ->each(function (Reservation $r) use (&$soon) {
                foreach ($r->table_ids as $id) {
                    $soon[$id] ??= $r; // đã sắp theo giờ: giữ lượt sớm nhất
                }
            });

        // Theo thứ tự tạo bàn (không xếp chữ cái) để các khu vực giữ thứ tự quán đặt: Tầng 1, Tầng 2, Ngoài trời...
        $tables = DiningTable::inArea($request->input('area'))
            ->orderBy('id')
            ->get()
            ->each(function (DiningTable $table) use ($soon) {
                $reservation = $soon[$table->id] ?? null;
                $at = $reservation?->date_time;
                $table->setAttribute('next_reservation_at', $at?->toIso8601String());
                $table->setAttribute('next_reservation', $reservation ? [
                    'id' => $reservation->id,
                    'code' => $reservation->code,
                    'date_time' => $reservation->date_time->toIso8601String(),
                    'guest_count' => $reservation->guest_count,
                    'customer_name' => $reservation->customer?->name,
                    'customer_phone' => $reservation->customer?->phone,
                    'deposit_amount' => $reservation->isDepositPaid() ? (float) $reservation->deposit_amount : null,
                ] : null);
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
     *  - Không nhận đặt theo DiningTable::isBookableAt (ngừng phục vụ, đang khóa, hoặc đang có
     *    khách và giờ đặt nằm trong 90 phút tới), HOẶC
     *  - Có lượt đặt bàn trong khoảng ±Reservation::WINDOW_MINUTES quanh giờ khách chọn.
     * ReservationController::store() dùng đúng hai điều kiện này nên kết quả luôn khớp.
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
        Reservation::expireStale();

        // Đổi về múi giờ của quán giống ReservationController::store(), nếu không giờ UTC
        // và giờ địa phương bị so lệch 7 tiếng → bàn hiện "Trống" nhưng đặt lại bị từ chối.
        $dt          = Carbon::parse($request->input('datetime'))->setTimezone(config('app.timezone'));
        $windowStart = $dt->copy()->subMinutes(Reservation::WINDOW_MINUTES);
        $windowEnd   = $dt->copy()->addMinutes(Reservation::WINDOW_MINUTES);

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
            ->map(function (DiningTable $table) use ($bookedIds, $dt) {
                $available = $table->isBookableAt($dt)
                    && ! in_array($table->id, $bookedIds);

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
