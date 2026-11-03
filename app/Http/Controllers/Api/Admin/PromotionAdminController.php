<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\PromotionResource;
use App\Models\Promotion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * CRUD khuyến mãi / voucher (chỉ Admin).
 *
 * Chính sách xóa: KHÔNG hard delete vì voucher đã được dùng trong hóa đơn cũ.
 * "Vô hiệu hóa" = set is_active = false và valid_to = now() (hết hạn ngay lập tức).
 */
class PromotionAdminController extends ApiController
{
    /**
     * GET /api/admin/promotions
     *
     * Tất cả khuyến mãi: đang hoạt động, sắp tới, đã hết hạn.
     * Dùng display_status để phân loại: active / upcoming / expired.
     */
    public function index(): JsonResponse
    {
        $promotions = Promotion::orderByDesc('valid_from')->get();

        return $this->ok($this->items($promotions, PromotionResource::class));
    }

    /**
     * POST /api/admin/promotions
     *
     * Tạo khuyến mãi mới.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'string', 'max:50', 'unique:promotions,code'],
            'title' => ['required', 'string', 'max:200'],
            'description' => ['nullable', 'string', 'max:500'],
            'discount_percent' => ['required', 'integer', 'min:1', 'max:100'],
            'max_discount' => ['nullable', 'numeric', 'min:0'],
            'min_order_amount' => ['nullable', 'numeric', 'min:0'],
            'valid_from' => ['required', 'date'],
            'valid_to' => ['required', 'date', 'after:valid_from'],
            'is_active' => ['boolean'],
        ]);

        $promotion = Promotion::create($data + ['is_active' => $data['is_active'] ?? true]);

        return $this->ok(PromotionResource::make($promotion)->resolve(request()), 'Thêm khuyến mãi thành công', 201);
    }

    /**
     * PUT /api/admin/promotions/{promotion}
     *
     * Cập nhật thông tin khuyến mãi.
     */
    public function update(Request $request, Promotion $promotion): JsonResponse
    {
        $data = $request->validate([
            'code' => ['sometimes', 'required', 'string', 'max:50', "unique:promotions,code,{$promotion->id}"],
            'title' => ['sometimes', 'required', 'string', 'max:200'],
            'description' => ['nullable', 'string', 'max:500'],
            'discount_percent' => ['sometimes', 'required', 'integer', 'min:1', 'max:100'],
            'max_discount' => ['nullable', 'numeric', 'min:0'],
            'min_order_amount' => ['nullable', 'numeric', 'min:0'],
            'valid_from' => ['sometimes', 'date'],
            'valid_to' => ['sometimes', 'date', 'after:valid_from'],
            'is_active' => ['boolean'],
        ]);

        $promotion->update($data);

        return $this->ok(PromotionResource::make($promotion->fresh())->resolve(request()), 'Cập nhật thành công');
    }

    /**
     * PATCH /api/admin/promotions/{promotion}/toggle-active
     *
     * Kích hoạt / Vô hiệu hóa khuyến mãi (không xóa).
     * Vô hiệu hóa sẽ đặt valid_to = now() để ngừng ngay lập tức.
     */
    public function toggleActive(Promotion $promotion): JsonResponse
    {
        if ($promotion->is_active) {
            // Vô hiệu hóa: đặt is_active = false và hết hạn ngay
            $promotion->update(['is_active' => false, 'valid_to' => now()]);
            $message = "Đã vô hiệu hóa khuyến mãi \"{$promotion->code}\"";
        } else {
            // Kích hoạt lại: chỉ set is_active = true (valid_to không thay đổi)
            $promotion->update(['is_active' => true]);
            $message = "Đã kích hoạt khuyến mãi \"{$promotion->code}\"";
        }

        return $this->ok(PromotionResource::make($promotion->fresh())->resolve(request()), $message);
    }
}
