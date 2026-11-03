<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\FoodResource;
use App\Models\Food;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * CRUD món ăn (chỉ Admin).
 *
 * Chính sách xóa: KHÔNG hard delete vì món đã xuất hiện trong hóa đơn cũ.
 * "Xóa" = set is_available = false (ẩn khỏi thực đơn, khách không order được).
 * Admin có thể bật lại bất cứ lúc nào.
 */
class FoodAdminController extends ApiController
{
    /**
     * GET /api/admin/foods?category_id=&search=&available=
     *
     * Admin xem tất cả món kể cả món đang ẩn (is_available = false).
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'category_id' => ['nullable', 'integer'],
            'search' => ['nullable', 'string', 'max:100'],
            'available' => ['nullable', 'boolean'],
        ]);

        $foods = Food::with('options')
            ->when($request->filled('category_id'), fn ($q) => $q->where('category_id', $request->integer('category_id')))
            ->when($request->filled('available'), fn ($q) => $q->where('is_available', $request->boolean('available')))
            ->when($request->filled('search'), function ($q) use ($request) {
                $s = '%' . $request->input('search') . '%';
                $q->where('name', 'like', $s);
            })
            ->orderBy('category_id')
            ->orderBy('name')
            ->get();

        return $this->ok($this->items($foods, FoodResource::class));
    }

    /**
     * POST /api/admin/foods
     *
     * Thêm món mới vào thực đơn.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'category_id' => ['required', 'integer', 'exists:categories,id'],
            'name' => ['required', 'string', 'max:150'],
            'price' => ['required', 'numeric', 'min:0'],
            'description' => ['nullable', 'string', 'max:500'],
            'image_url' => ['nullable', 'url', 'max:500'],
            'is_available' => ['boolean'],
            'is_best_seller' => ['boolean'],
        ]);

        $food = Food::create($data + ['is_available' => true]);

        return $this->ok(FoodResource::make($food->load('options'))->resolve(request()), 'Thêm món thành công', 201);
    }

    /**
     * PUT /api/admin/foods/{food}
     *
     * Cập nhật thông tin món.
     */
    public function update(Request $request, Food $food): JsonResponse
    {
        $data = $request->validate([
            'category_id' => ['sometimes', 'integer', 'exists:categories,id'],
            'name' => ['sometimes', 'required', 'string', 'max:150'],
            'price' => ['sometimes', 'required', 'numeric', 'min:0'],
            'description' => ['nullable', 'string', 'max:500'],
            'image_url' => ['nullable', 'url', 'max:500'],
            'is_available' => ['boolean'],
            'is_best_seller' => ['boolean'],
        ]);

        $food->update($data);

        return $this->ok(FoodResource::make($food->fresh()->load('options'))->resolve(request()), 'Cập nhật thành công');
    }

    /**
     * PATCH /api/admin/foods/{food}/toggle-available
     *
     * Hiện / Ẩn món (thay vì xóa thật). Dùng khi món hết nguyên liệu dài hạn
     * hoặc admin muốn tạm ngừng bán nhưng giữ lịch sử.
     */
    public function toggleAvailable(Food $food): JsonResponse
    {
        $food->update(['is_available' => !$food->is_available]);

        $message = $food->fresh()->is_available
            ? "Đã hiện món \"{$food->name}\" trong thực đơn"
            : "Đã ẩn món \"{$food->name}\" khỏi thực đơn";

        return $this->ok(FoodResource::make($food->fresh()->load('options'))->resolve(request()), $message);
    }
}
