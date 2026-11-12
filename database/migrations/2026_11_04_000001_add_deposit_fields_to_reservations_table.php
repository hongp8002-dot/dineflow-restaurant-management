<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            // Số tiền cọc = 50% tổng món đặt trước, làm tròn lên 100đ. null = không có cọc.
            $table->decimal('deposit_amount', 12, 2)->nullable()->after('pre_order_payment');
            // Thời điểm khách đã thanh toán cọc (VietQR giả lập trong app). null = chưa thanh toán.
            $table->timestamp('deposit_paid_at')->nullable()->after('deposit_amount');
        });
    }

    public function down(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            $table->dropColumn(['deposit_amount', 'deposit_paid_at']);
        });
    }
};
