<?php

namespace Tests\Feature;

use App\Enums\ReservationStatus;
use App\Models\DiningTable;
use App\Models\Food;
use App\Models\Reservation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** Admin xóa món: xóa được món không còn dùng; chặn món đang trong đơn chưa thanh toán / món đặt trước. */
class FoodDeleteTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    private function actAs(string $email): void
    {
        Sanctum::actingAs(User::where('email', $email)->firstOrFail());
    }

    public function test_admin_deletes_unused_food(): void
    {
        $food = Food::create(['category_id' => Food::first()->category_id, 'name' => 'Món thêm nhầm', 'price' => 10000, 'is_available' => true]);

        $this->actAs('admin@dineflow.com');
        $this->deleteJson("/api/admin/foods/{$food->id}")->assertOk();

        $this->assertNull(Food::find($food->id));
    }

    public function test_food_in_unpaid_order_cannot_be_deleted(): void
    {
        $food = Food::where('name', 'Cơm sườn nướng')->firstOrFail();
        $this->actAs('staff@dineflow.com');
        $table = DiningTable::where('status', 'empty')->orderByDesc('id')->firstOrFail();
        $this->postJson('/api/orders', ['table_id' => $table->id, 'items' => [['food_id' => $food->id, 'quantity' => 1]]])->assertCreated();

        $this->actAs('admin@dineflow.com');
        $this->deleteJson("/api/admin/foods/{$food->id}")->assertStatus(422)->assertJsonPath('status', 'error');
        $this->assertNotNull(Food::find($food->id));
    }

    public function test_food_in_upcoming_pre_order_cannot_be_deleted(): void
    {
        $food = Food::create(['category_id' => Food::first()->category_id, 'name' => 'Món đặt trước', 'price' => 20000, 'is_available' => true]);
        Reservation::create([
            'customer_id' => User::where('email', 'customer@dineflow.com')->value('id'),
            'table_ids' => [DiningTable::first()->id],
            'area' => 'Tầng 1',
            'date_time' => now()->addDay(),
            'guest_count' => 2,
            'status' => ReservationStatus::Upcoming,
            'pre_order_items' => [['food_id' => $food->id, 'food_name' => $food->name, 'quantity' => 1, 'price' => 20000, 'options' => []]],
        ]);

        $this->actAs('admin@dineflow.com');
        $this->deleteJson("/api/admin/foods/{$food->id}")->assertStatus(422);
        $this->assertNotNull(Food::find($food->id));
    }

    public function test_non_admin_cannot_delete_food(): void
    {
        $food = Food::first();
        $this->actAs('cashier@dineflow.com');
        $this->deleteJson("/api/admin/foods/{$food->id}")->assertStatus(403);
    }
}
