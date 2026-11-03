<?php

use App\Enums\TableStatus;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tables', function (Blueprint $table) {
            $table->id();
            $table->string('number', 30)->unique(); // 'Bàn 1'
            $table->string('area', 50);             // 'Tầng 1', 'Ngoài trời'...
            $table->unsignedSmallInteger('capacity')->default(4);
            $table->enum('status', array_column(TableStatus::cases(), 'value'))->default(TableStatus::Empty->value);
            $table->timestamp('serving_since')->nullable();
            // FK tới orders được thêm trong migration create_orders_table (tránh phụ thuộc vòng)
            $table->unsignedBigInteger('current_order_id')->nullable();
            $table->timestamps();

            $table->index(['area', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tables');
    }
};
