<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * CRUD danh mục món ăn (chỉ Admin).
 *
 * Danh mục CÓ THỂ hard delete nếu không có món nào thuộc về — trường hợp đó
 * server sẽ báo lỗi thay vì cascade xóa món (tránh mất dữ liệu không cố ý).
 */
class CategoryAdminController extends ApiController
{
    /**
     * GET /api/admin/categories
     */
    public function index(): JsonResponse
    {
        return $this->ok($this->items(Category::ordered()->get(), CategoryResource::class));
    }

    /**
     * POST /api/admin/categories
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            // Tên danh mục là duy nhất trong DB (unique) → báo lỗi rõ ràng thay vì lỗi 500
            'name' => ['required', 'string', 'max:100', 'unique:categories,name'],
            'icon' => ['nullable', 'string', 'max:50'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
        ]);

        $category = Category::create($data + ['sort_order' => $data['sort_order'] ?? Category::max('sort_order') + 1]);

        return $this->ok(CategoryResource::make($category)->resolve(request()), 'Thêm danh mục thành công', 201);
    }

    /**
     * PUT /api/admin/categories/{category}
     */
    public function update(Request $request, Category $category): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:100', Rule::unique('categories', 'name')->ignore($category->id)],
            'icon' => ['nullable', 'string', 'max:50'],
            'sort_order' => ['nullable', 'integer', 'min:0'],
        ]);

        $category->update($data);

        return $this->ok(CategoryResource::make($category->fresh())->resolve(request()), 'Cập nhật thành công');
    }

    /**
     * DELETE /api/admin/categories/{category}
     *
     * Chỉ cho xóa nếu không còn món nào trong danh mục.
     * Nếu còn món → trả lỗi 422 kèm số lượng món còn lại để admin xử lý trước.
     */
    public function destroy(Category $category): JsonResponse
    {
        // Cùng quy tắc với trang Danh mục trên web /admin
        if ($reason = $category->deletionBlockedReason()) {
            return $this->fail($reason, 422);
        }

        $name = $category->name;
        $category->delete();

        return $this->ok(null, "Đã xóa danh mục \"$name\"");
    }
}
