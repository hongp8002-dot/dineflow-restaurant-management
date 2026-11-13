<?php

/*
|--------------------------------------------------------------------------
| Thông tin nhà hàng dùng chung cho app
|--------------------------------------------------------------------------
| Tài khoản nhận chuyển khoản dùng để tạo mã VietQR (khách đặt cọc, thu ngân thu tiền).
| Đổi trong file .env khi triển khai thật; giá trị mặc định dưới đây chỉ là tài khoản DEMO.
| App Flutter tải về qua GET /api/settings, không viết cứng trong app nữa.
*/

return [
    'name' => env('RESTAURANT_NAME', 'DineFlow Restaurant'),

    // Múi giờ của quán. Database vẫn lưu giờ UTC (config app.timezone); múi giờ này dùng để
    // HIỂN THỊ trên web /admin và để tính "một ngày" của quán (lọc lịch đặt bàn, báo cáo ca).
    // App Flutter tự đổi sang giờ của điện thoại nên không phụ thuộc giá trị này.
    'timezone' => env('RESTAURANT_TIMEZONE', 'Asia/Ho_Chi_Minh'),

    'bank' => [
        // Mã ngân hàng theo VietQR (vd VCB, TCB, MB...)
        'code' => env('RESTAURANT_BANK_CODE', 'VCB'),
        'name' => env('RESTAURANT_BANK_NAME', 'VCB – Vietcombank'),
        'account_no' => env('RESTAURANT_BANK_ACCOUNT_NO', '1234567890'),
        'account_name' => env('RESTAURANT_BANK_ACCOUNT_NAME', 'DINEFLOW RESTAURANT'),
    ],
];
