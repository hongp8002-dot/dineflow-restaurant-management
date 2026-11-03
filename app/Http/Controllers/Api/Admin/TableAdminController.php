<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\TableStatus;
use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\TableResource;
use App\Models\DiningTable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * CRUD bàn ăn (chỉ Admin).
 *
 * Bàn đã có lịch sử đơn hàng KHÔNG được hard delete — chỉ set is_active = false.
 * is_locked: NV Order không thể mở bàn bị khóa (khóa tạm, bàn vẫn hiển thị).
 * is_active: Ẩn bàn hoàn toàn khỏi hệ thống (bàn bị tháo bỏ, khu vực đóng).
 */
class TableAdminController extends ApiController
{
    /**
     * GET /api/admin/tables?area=
     *
     * Admin xem TẤT CẢ bàn kể cả bàn inactive (is_active = false).
     */
    public function index(Request $request): JsonResponse
    {
        $tables = DiningTable::inArea($request->input('area'))
            ->orderBy('id')
            ->get();

        return $this->ok($this->items($tables, TableResource::class), 'Thành công', 200, [
            'areas' => DiningTable::query()->groupBy('area')->orderByRaw('MIN(id)')->pluck('area'),
        ]);
    }

    /**
     * POST /api/admin/tables
     *
     * Thêm bàn mới.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'number' => ['required', 'string', 'max:20'],
            'area' => ['required', 'string', 'max:50'],
            'capacity' => ['required', 'integer', 'min:1', 'max:50'],
        ]);

        $table = DiningTable::create([
            ...$data,
            'status' => TableStatus::Empty,
            'is_locked' => false,
            'is_active' => true,
        ]);

        return $this->ok(TableResource::make($table)->resolve(request()), 'Thêm bàn thành công', 201);
    }

    /**
     * PUT /api/admin/tables/{table}
     *
     * Cập nhật thông tin bàn (số bàn, khu vực, sức chứa).
     */
    public function update(Request $request, DiningTable $table): JsonResponse
    {
        $data = $request->validate([
            'number' => ['sometimes', 'required', 'string', 'max:20'],
            'area' => ['sometimes', 'required', 'string', 'max:50'],
            'capacity' => ['sometimes', 'required', 'integer', 'min:1', 'max:50'],
        ]);

        $table->update($data);

        return $this->ok(TableResource::make($table->fresh())->resolve(request()), 'Cập nhật thành công');
    }

    /**
     * PATCH /api/admin/tables/{table}/toggle-locked
     *
     * Khóa / Mở khóa bàn.
     * Bàn bị khóa: vẫn hiển thị, NV Order không thể mở bàn mới.
     * Bàn đang có khách (serving) vẫn khóa được — khách đang ngồi vẫn phục vụ bình thường,
     * chỉ chặn mở bàn mới khi bàn trống.
     */
    public function toggleLocked(DiningTable $table): JsonResponse
    {
        $table->update(['is_locked' => !$table->is_locked]);

        $message = $table->fresh()->is_locked
            ? "Đã khóa bàn {$table->number}"
            : "Đã mở khóa bàn {$table->number}";

        return $this->ok(TableResource::make($table->fresh())->resolve(request()), $message);
    }

    /**
     * PATCH /api/admin/tables/{table}/toggle-active
     *
     * Vô hiệu hóa / Kích hoạt bàn.
     * Bàn inactive bị ẩn hoàn toàn khỏi app (không hiển thị cho NV hay khách).
     * Chỉ dùng khi bàn bị tháo bỏ hoặc khu vực đóng dài hạn.
     *
     * Không cho vô hiệu hóa bàn đang phục vụ (có khách).
     */
    public function toggleActive(DiningTable $table): JsonResponse
    {
        if ($table->is_active && $table->status === TableStatus::Serving) {
            return $this->fail(
                "Không thể vô hiệu hóa bàn {$table->number} đang có khách. Hãy xử lý đơn hàng trước.",
                422
            );
        }

        $table->update(['is_active' => !$table->is_active]);

        $message = $table->fresh()->is_active
            ? "Đã kích hoạt bàn {$table->number}"
            : "Đã vô hiệu hóa bàn {$table->number}";

        return $this->ok(TableResource::make($table->fresh())->resolve(request()), $message);
    }
}
