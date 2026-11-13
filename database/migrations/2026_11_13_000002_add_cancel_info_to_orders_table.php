<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Lưu thông tin hủy đơn (nhóm chốt 13/11, cách A): lý do, ghi chú, ai hủy, lúc nào.
 * Quan hệ: orders.cancelled_by → users (nhiều đơn có thể do một người hủy). Người hủy bị xóa
 * thì giữ đơn, chỉ để trống cột người hủy.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->string('cancel_reason', 30)->nullable()->after('note'); // App\Enums\CancelReason
            $table->string('cancel_note', 255)->nullable()->after('cancel_reason');
            $table->foreignId('cancelled_by')->nullable()->after('cancel_note')->constrained('users')->nullOnDelete();
            $table->timestamp('cancelled_at')->nullable()->after('cancelled_by')->index();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropConstrainedForeignId('cancelled_by');
            $table->dropColumn(['cancel_reason', 'cancel_note', 'cancelled_at']);
        });
    }
};
