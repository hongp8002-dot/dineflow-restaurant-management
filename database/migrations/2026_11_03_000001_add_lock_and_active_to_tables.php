<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Thêm 2 cột vào bảng `tables`:
 *
 *  - `is_locked`  (bool, mặc định false): Admin khóa bàn — NV Order không thể mở bàn bị khóa.
 *                  Orthogonal với operational status (empty/serving/reserved).
 *                  Dùng khi bàn đang sửa chữa, vệ sinh lâu, hoặc cần giữ chỗ.
 *
 *  - `is_active`  (bool, mặc định true): Admin ẩn/vô hiệu hóa bàn khỏi hệ thống
 *                  (bàn bị tháo bỏ, khu vực tạm đóng...). App không hiển thị bàn inactive.
 *
 * Hai cột này độc lập nhau và độc lập với cột `status` (empty/serving/reserved).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tables', function (Blueprint $table) {
            $table->boolean('is_locked')->default(false)->after('current_order_id')
                ->comment('Admin khóa bàn – NV không thể mở, vẫn hiển thị');
            $table->boolean('is_active')->default(true)->after('is_locked')
                ->comment('false = ẩn khỏi app hoàn toàn (bàn bị tháo bỏ)');
        });
    }

    public function down(): void
    {
        Schema::table('tables', function (Blueprint $table) {
            $table->dropColumn(['is_locked', 'is_active']);
        });
    }
};
