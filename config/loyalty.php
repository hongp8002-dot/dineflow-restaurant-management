<?php

/*
|--------------------------------------------------------------------------
| Quy tắc thành viên Kiểu A (nhóm chốt 23/10/2026)
|--------------------------------------------------------------------------
| - Điểm chỉ dùng để xét hạng, không bao giờ bị trừ hay đổi thành tiền.
| - Cứ mỗi `amount_per_step` đồng khách THỰC TRẢ thì được `points_per_step` điểm.
| - Mỗi hạng được giảm `discount_percent` % trên hóa đơn; không cộng dồn với voucher
|   (lấy mức giảm cao hơn).
|
| Đây là NƠI DUY NHẤT chứa các con số này. Backend (thanh toán, tra cứu thành viên) đọc qua
| App\Services\LoyaltyRules; app Flutter tải về qua GET /api/settings.
*/

return [
    'amount_per_step' => 10000,
    'points_per_step' => 2,

    // Thứ tự từ thấp đến cao. Tên hạng khớp enum MemberTier bên Flutter.
    'tiers' => [
        'silver' => ['label' => 'Bạc', 'min_points' => 0, 'discount_percent' => 0],
        'gold' => ['label' => 'Vàng', 'min_points' => 500, 'discount_percent' => 5],
        'platinum' => ['label' => 'Kim cương', 'min_points' => 1500, 'discount_percent' => 10],
    ],
];
