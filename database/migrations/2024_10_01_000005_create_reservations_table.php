<?php

use App\Enums\PaymentMethod;
use App\Enums\ReservationStatus;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reservations', function (Blueprint $table) {
            $table->id();
            $table->string('code', 20)->unique(); // DF-8921
            $table->foreignId('customer_id')->constrained('users')->cascadeOnDelete();
            $table->json('table_ids');            // [1, 2] khi ghép bàn
            $table->string('area', 50);
            $table->dateTime('date_time');
            $table->unsignedSmallInteger('guest_count');
            $table->text('note')->nullable();
            $table->enum('status', array_column(ReservationStatus::cases(), 'value'))->default(ReservationStatus::Upcoming->value);
            $table->json('pre_order_items')->nullable();
            // Phương thức khách chọn cho món đặt trước (Flutter: preOrderPayment), null nếu không đặt món
            $table->enum('pre_order_payment', array_column(PaymentMethod::cases(), 'value'))->nullable();
            $table->timestamps();

            $table->index(['customer_id', 'status']);
            $table->index(['date_time', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reservations');
    }
};
