<?php

use App\Enums\ShiftStatus;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shifts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('cashier_id')->constrained('users')->cascadeOnDelete();
            $table->enum('status', array_column(ShiftStatus::cases(), 'value'))->default(ShiftStatus::Open->value);
            // Tiền mặt đầu ca (do thu ngân nhập khi mở ca)
            $table->decimal('opening_cash', 12, 2)->default(0);
            // Tiền mặt thu ngân đếm được lúc đóng ca
            $table->decimal('closing_cash_counted', 12, 2)->nullable();
            $table->timestamp('opened_at');
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();

            $table->index(['cashier_id', 'status']); // tra ca đang mở
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shifts');
    }
};
