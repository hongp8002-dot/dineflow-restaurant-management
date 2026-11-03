<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained()->cascadeOnDelete();
            $table->foreignId('food_id')->nullable()->constrained('foods')->nullOnDelete();
            $table->string('food_name');             // snapshot tên món lúc đặt (Flutter: OrderItem.foodName)
            $table->unsignedSmallInteger('quantity')->default(1);
            $table->json('options')->nullable();     // [{id, group, name, price_modifier}]
            $table->decimal('price', 12, 2);         // đơn giá gốc lúc đặt (chưa gồm options)
            $table->text('note')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_items');
    }
};
