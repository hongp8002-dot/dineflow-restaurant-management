<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('food_options', function (Blueprint $table) {
            $table->id();
            $table->foreignId('food_id')->constrained('foods')->cascadeOnDelete();
            $table->string('name');
            $table->string('group', 30)->default('size'); // FoodOptionGroup: size | topping
            $table->decimal('price_modifier', 12, 2)->default(0);
            $table->timestamps();

            $table->index(['food_id', 'group']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('food_options');
    }
};
