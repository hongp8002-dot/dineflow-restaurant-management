<?php

namespace Tests\Feature;

use App\Models\Promotion;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Tắt khuyến mãi chỉ ngừng áp dụng, không ghi đè ngày kết thúc; bật lại dùng tiếp đúng thời hạn cũ. */
class PromotionToggleTest extends TestCase
{
    use RefreshDatabase;

    public function test_turn_off_then_on_keeps_original_end_date(): void
    {
        $this->seed();
        Sanctum::actingAs(User::where('email', 'admin@dineflow.com')->firstOrFail());
        $promo = Promotion::where('code', 'WELCOME10')->firstOrFail();
        $endDate = $promo->valid_to->toIso8601String();

        $off = $this->patchJson("/api/admin/promotions/{$promo->id}/toggle-active")->assertOk()->json('data');
        $this->assertFalse($off['is_active']);
        $this->assertSame($endDate, $off['valid_to'], 'Tắt không được đổi ngày kết thúc');
        $this->assertFalse($promo->fresh()->isApplicableTo(1_000_000), 'Đã tắt thì không áp dụng được');

        $on = $this->patchJson("/api/admin/promotions/{$promo->id}/toggle-active")->assertOk()->json('data');
        $this->assertTrue($on['is_active']);
        $this->assertSame('active', $on['status']);
        $this->assertSame($endDate, $on['valid_to']);
    }
}
