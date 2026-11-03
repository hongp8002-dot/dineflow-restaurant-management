<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('foods', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->constrained()->cascadeOnUpdate()->restrictOnDelete();
            $table->string('name');
            $table->decimal('price', 12, 2);
            $table->text('description')->nullable();
            $table->string('image')->nullable();      // path trong disk 'public' hoặc URL http(s)
            $table->string('icon', 50)->nullable();   // fallback icon khi không có ảnh (Flutter: Food.icon)
            $table->string('color', 9)->nullable();   // mã màu hex, vd '#8B5A2B' (Flutter: Food.color)
            $table->decimal('rating', 2, 1)->default(4.5);
            $table->boolean('is_best_seller')->default(false);
            $table->boolean('is_available')->default(true);
            $table->timestamps();

            $table->index(['category_id', 'is_available']);
            $table->index('name');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('foods');
    }
};
