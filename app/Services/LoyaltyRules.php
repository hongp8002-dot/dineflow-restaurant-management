<?php

namespace App\Services;

/**
 * Quy tắc thành viên Kiểu A, đọc từ config/loyalty.php.
 * Mọi nơi trong backend cần hạng / % giảm / điểm cộng đều gọi qua đây, không viết số trực tiếp.
 */
class LoyaltyRules
{
    /** Tên hạng (silver / gold / platinum) ứng với số điểm tích lũy. */
    public static function tierFor(int $points): string
    {
        $tier = 'silver';
        foreach (config('loyalty.tiers') as $name => $rule) {
            if ($points >= $rule['min_points']) {
                $tier = $name; // các hạng xếp từ thấp đến cao nên hạng cuối thỏa mãn là hạng cao nhất đạt được
            }
        }

        return $tier;
    }

    /** % giảm trên hóa đơn của hạng ứng với số điểm. */
    public static function discountPercentFor(int $points): int
    {
        return (int) config('loyalty.tiers.'.self::tierFor($points).'.discount_percent');
    }

    /** Điểm được cộng cho số tiền khách thực trả, làm tròn xuống theo từng mức. Vd 95.000đ → 18 điểm. */
    public static function pointsEarned(float $paidAmount): int
    {
        if ($paidAmount <= 0) {
            return 0;
        }

        return (int) floor($paidAmount / config('loyalty.amount_per_step')) * (int) config('loyalty.points_per_step');
    }
}
