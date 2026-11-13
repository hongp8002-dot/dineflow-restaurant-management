<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Trước đây dữ liệu mẫu ghi cứng `tables.status = 'reserved'` cho bàn có lượt đặt.
 * Trạng thái đó không bao giờ được trả về `empty`, khiến bàn bị chặn đặt và NV Order
 * không mở được bàn ở mọi giờ.
 *
 * Từ nay cột `tables.status` chỉ phản ánh tình trạng NGAY LÚC NÀY (trống / đang phục vụ).
 * "Đã đặt trước" được tính từ bảng `reservations` (xem TableController), nên migration
 * này đưa các bàn đang `reserved` về `empty`. Bàn đang có khách (`serving`) giữ nguyên.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::table('tables')->where('status', 'reserved')->update(['status' => 'empty']);
    }

    public function down(): void
    {
        // Không khôi phục: không còn biết bàn nào từng bị gán 'reserved'.
    }
};
