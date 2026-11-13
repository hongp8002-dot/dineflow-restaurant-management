<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Models\User;
use App\Services\LoyaltyRules;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Tra cứu thành viên theo mã thẻ (dùng cho màn Quét QR của Thu ngân).
 *
 * GET /api/members/{code}
 */
class MemberController extends ApiController
{
    public function show(Request $request, string $code): JsonResponse
    {
        $customer = User::where('member_code', strtoupper(trim($code)))
            ->where('role', UserRole::Customer)
            ->where('status', 'active')
            ->first();

        if (! $customer) {
            return $this->fail('Không tìm thấy thành viên có mã "' . $code . '".', 404);
        }

        return $this->ok($this->formatMember($customer));
    }

    private function formatMember(User $user): array
    {
        // Hạng theo điểm, ngưỡng lấy từ config/loyalty.php (app Flutter tải cùng quy tắc qua /api/settings)
        $tier = LoyaltyRules::tierFor((int) $user->points);

        return [
            'id'          => $user->id,
            'name'        => $user->name,
            'phone'       => $user->phone,
            'member_code' => $user->member_code,
            'points'      => $user->points,
            'tier'        => $tier,
        ];
    }
}
