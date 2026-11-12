<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            // Tiền cọc được khấu trừ trong hóa đơn này (từ đặt bàn kèm món trước).
            $table->decimal('deposit_amount', 12, 2)->default(0)->after('total');
        });
    }

    public function down(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->dropColumn('deposit_amount');
        });
    }
};
