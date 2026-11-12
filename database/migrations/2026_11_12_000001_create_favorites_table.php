<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('favorites', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('food_id')->constrained('foods')->cascadeOnDelete();
            $table->timestamps();

            // Mỗi khách chỉ yêu thích một món một lần
            $table->unique(['customer_id', 'food_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('favorites');
    }
};
