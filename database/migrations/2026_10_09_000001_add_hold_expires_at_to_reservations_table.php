<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            // Lượt đặt đang "giữ bàn" chờ khách xác nhận: có hạn. null = đã xác nhận (không hết hạn).
            $table->timestamp('hold_expires_at')->nullable()->after('status')->index();
        });
    }

    public function down(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            $table->dropColumn('hold_expires_at');
        });
    }
};
