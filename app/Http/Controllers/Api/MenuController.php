<?php

namespace App\Http\Controllers\Api;

use App\Http\Resources\CategoryResource;
use App\Http\Resources\FoodResource;
use App\Http\Resources\PromotionResource;
use App\Models\Category;
use App\Models\Food;
use App\Models\Promotion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MenuController extends ApiController
{
    public function categories(): JsonResponse
    {
        return $this->ok($this->items(Category::ordered()->get(), CategoryResource::class));
    }

    /**
     * GET /api/foods?category_id=&search=&available=1&best_seller=1
     * Mặc định trả cả món hết hàng (is_available = false) để app hiển thị mờ đi.
     */
    public function foods(Request $request): JsonResponse
    {
        $request->validate([
            'category_id' => ['nullable', 'integer'],
            'search' => ['nullable', 'string', 'max:100'],
            'available' => ['nullable', 'boolean'],
            'best_seller' => ['nullable', 'boolean'],
        ]);

        $foods = Food::with('options')
            ->when($request->filled('category_id'), fn ($q) => $q->where('category_id', $request->integer('category_id')))
            ->when($request->boolean('available'), fn ($q) => $q->available())
            ->when($request->boolean('best_seller'), fn ($q) => $q->where('is_best_seller', true))
            ->search($request->input('search'))
            ->orderBy('category_id')
            ->orderBy('name')
            ->get();

        return $this->ok($this->items($foods, FoodResource::class));
    }

    /** Voucher đang trong thời gian hiệu lực. */
    public function promotions(): JsonResponse
    {
        return $this->ok($this->items(Promotion::valid()->orderBy('valid_to')->get(), PromotionResource::class));
    }
}
