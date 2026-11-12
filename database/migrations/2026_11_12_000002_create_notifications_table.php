<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Bảng thông báo in-app cho khách hàng.
 *
 * Chỉ lưu thông báo liên quan đến đặt bàn (đặt thành công, hủy).
 * Firebase push notification (thông báo đẩy khi app đóng) do bạn khác xử lý riêng.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();

            // Khách nhận thông báo — xóa user thì xóa thông báo luôn
            $table->foreignId('customer_id')
                ->constrained('users')
                ->cascadeOnDelete();

            // Loại thông báo: reservation_confirmed | reservation_cancelled
            $table->string('type', 60);

            $table->string('title');
            $table->string('body');

            // Dữ liệu kèm theo, vd: {"reservation_id": 5}
            $table->json('data')->nullable();

            // null = chưa đọc; có giá trị = đã đọc
            $table->timestamp('read_at')->nullable();

            $table->timestamps();

            // Lấy thông báo chưa đọc của một khách hàng nhanh
            $table->index(['customer_id', 'read_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
