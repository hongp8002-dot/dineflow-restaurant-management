<?php

namespace App\Http\Controllers\Api;

use App\Http\Resources\FoodResource;
use App\Models\Favorite;
use App\Models\Food;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FavoriteController extends ApiController
{
    /**
     * GET /customers/me/favorites
     * Danh sách món yêu thích của khách đang đăng nhập.
     */
    public function index(Request $request): JsonResponse
    {
        $favorites = Favorite::where('customer_id', $request->user()->id)
            ->with(['food.options'])
            ->get()
            ->pluck('food')
            ->filter()
            ->values();

        return $this->ok(FoodResource::collection($favorites)->resolve());
    }

    /**
     * POST /customers/me/favorites/{food}
     * Toggle yêu thích: thêm nếu chưa có, xóa nếu đã có.
     */
    public function toggle(Request $request, Food $food): JsonResponse
    {
        $customerId = $request->user()->id;

        $existing = Favorite::where('customer_id', $customerId)
            ->where('food_id', $food->id)
            ->first();

        if ($existing) {
            $existing->delete();
            $favorited = false;
        } else {
            Favorite::create(['customer_id' => $customerId, 'food_id' => $food->id]);
            $favorited = true;
        }

        return $this->ok(
            ['favorited' => $favorited],
            $favorited ? 'Đã thêm vào yêu thích' : 'Đã bỏ khỏi yêu thích'
        );
    }
}
