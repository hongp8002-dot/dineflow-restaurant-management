<?php

namespace App\Http\Controllers\Api;

use Illuminate\Http\JsonResponse;

/**
 * GET /api/settings  (mọi vai trò đã đăng nhập)
 *
 * Cấu hình dùng chung cho app: tài khoản nhận chuyển khoản (tạo mã VietQR) và quy tắc thành viên.
 * Nguồn: config/restaurant.php và config/loyalty.php — app không viết cứng các giá trị này nữa.
 */
class SettingsController extends ApiController
{
    public function show(): JsonResponse
    {
        return $this->ok([
            'restaurant' => config('restaurant'),
            'loyalty' => config('loyalty'),
        ]);
    }
}
