<?php

namespace Tests\Feature;

use App\Models\DiningTable;
use App\Models\Food;
use App\Models\Invoice;
use App\Models\OrderItem;
use App\Models\Reservation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ApiFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed();
    }

    private function actAs(string $role): User
    {
        $email = ['admin' => 'admin@dineflow.com', 'staff' => 'staff@dineflow.com', 'cashier' => 'cashier@dineflow.com', 'customer' => 'customer@dineflow.com'][$role];
        $user = User::where('email', $email)->firstOrFail();
        Sanctum::actingAs($user);

        return $user;
    }

    private function table(string $number): DiningTable
    {
        return DiningTable::where('number', $number)->firstOrFail();
    }

    /** Cà phê sữa đá (29.000) + Size M (8.000) x2 = 74.000 */
    private function coffeeLine(int $qty = 2): array
    {
        $food = Food::where('name', 'Cà phê sữa đá')->firstOrFail();

        return [
            'food_id' => $food->id,
            'quantity' => $qty,
            'option_ids' => [$food->options()->where('name', 'Size M')->value('id')],
            'price' => 1, // client cố gửi giá giả, server phải bỏ qua
        ];
    }

    // ------------------------------------------------------------ Auth

    public function test_login_returns_token_and_user(): void
    {
        $this->postJson('/api/login', ['email' => 'admin@dineflow.com', 'password' => '123456'])
            ->assertOk()
            ->assertJsonPath('status', 'success')
            ->assertJsonPath('data.user.role', 'admin')
            ->assertJsonStructure(['status', 'message', 'data' => ['token', 'token_type', 'user' => ['id', 'name', 'email', 'role']]]);
    }

    public function test_login_accepts_phone_number_in_any_format_or_email_via_login_field(): void
    {
        // Số điện thoại có khoảng trắng / dấu chấm như người dùng hay gõ
        $this->postJson('/api/login', ['login' => '0900 000.002', 'password' => '123456'])
            ->assertOk()->assertJsonPath('data.user.email', 'staff@dineflow.com');

        $this->postJson('/api/login', ['login' => 'cashier@dineflow.com', 'password' => '123456'])
            ->assertOk()->assertJsonPath('data.user.role', 'cashier');

        $this->postJson('/api/login', ['login' => '0999999999', 'password' => '123456'])->assertStatus(401);
        $this->postJson('/api/login', ['login' => '---', 'password' => '123456'])->assertStatus(401);
    }

    public function test_login_with_wrong_password_is_rejected(): void
    {
        $this->postJson('/api/login', ['email' => 'admin@dineflow.com', 'password' => 'sai'])
            ->assertStatus(401)
            ->assertJsonPath('status', 'error')
            ->assertJsonPath('data', null);
    }

    public function test_user_can_change_own_password_and_other_tokens_are_revoked(): void
    {
        $staff = User::where('email', 'staff@dineflow.com')->first();
        $otherDevice = $staff->createToken('may-khac')->plainTextToken;
        $thisDevice = $staff->createToken('may-nay')->plainTextToken;
        $auth = fn (string $t) => $this->withHeader('Authorization', "Bearer {$t}");

        // Sai mật khẩu hiện tại
        $auth($thisDevice)->patchJson('/api/me/password', [
            'current_password' => 'sai', 'password' => 'moi1234', 'password_confirmation' => 'moi1234',
        ])->assertStatus(422)->assertJsonPath('message', 'Mật khẩu hiện tại không đúng.');

        // Xác nhận không khớp / quá ngắn / trùng mật khẩu cũ
        $auth($thisDevice)->patchJson('/api/me/password', [
            'current_password' => '123456', 'password' => 'moi1234', 'password_confirmation' => 'khac',
        ])->assertStatus(422)->assertJsonValidationErrors('password');
        $auth($thisDevice)->patchJson('/api/me/password', [
            'current_password' => '123456', 'password' => '123', 'password_confirmation' => '123',
        ])->assertStatus(422)->assertJsonValidationErrors('password');
        $auth($thisDevice)->patchJson('/api/me/password', [
            'current_password' => '123456', 'password' => '123456', 'password_confirmation' => '123456',
        ])->assertStatus(422)->assertJsonValidationErrors('password');

        // Thành công
        $auth($thisDevice)->patchJson('/api/me/password', [
            'current_password' => '123456', 'password' => 'moi1234', 'password_confirmation' => 'moi1234',
        ])->assertOk()->assertJsonPath('status', 'success');

        // Đăng nhập: mật khẩu mới được, mật khẩu cũ bị từ chối
        $this->postJson('/api/login', ['login' => 'staff@dineflow.com', 'password' => 'moi1234'])->assertOk();
        $this->postJson('/api/login', ['login' => 'staff@dineflow.com', 'password' => '123456'])->assertStatus(401);

        // Token máy đang dùng còn, token máy khác bị thu hồi
        $this->assertDatabaseHas('personal_access_tokens', ['tokenable_id' => $staff->id, 'name' => 'may-nay']);
        $this->assertDatabaseMissing('personal_access_tokens', ['tokenable_id' => $staff->id, 'name' => 'may-khac']);
        $this->app['auth']->forgetGuards();
        $auth($otherDevice)->getJson('/api/me')->assertStatus(401);
    }

    public function test_change_password_requires_login(): void
    {
        $this->patchJson('/api/me/password', [
            'current_password' => '123456', 'password' => 'moi1234', 'password_confirmation' => 'moi1234',
        ])->assertStatus(401);
    }

    public function test_locked_account_cannot_login_nor_use_old_token(): void
    {
        $this->postJson('/api/login', ['email' => 'locked@dineflow.com', 'password' => '123456'])
            ->assertStatus(403);

        $staff = User::where('email', 'staff@dineflow.com')->first();
        $token = $staff->createToken('t')->plainTextToken;
        $staff->update(['status' => 'locked']);

        $this->withHeader('Authorization', "Bearer {$token}")->getJson('/api/me')->assertStatus(403);
    }

    public function test_validation_and_unauthenticated_errors_use_the_same_json_shape(): void
    {
        $this->postJson('/api/login', [])
            ->assertStatus(422)
            ->assertJsonPath('status', 'error')
            ->assertJsonStructure(['status', 'message', 'data', 'errors' => ['email', 'password']]);

        $this->getJson('/api/foods')->assertStatus(401)->assertJsonPath('status', 'error');
        $this->get('/api/foods')->assertStatus(401)->assertJsonPath('status', 'error'); // không gửi Accept: json
    }

    public function test_register_always_creates_a_customer(): void
    {
        $this->postJson('/api/register', [
            'name' => 'Khách Mới', 'email' => 'moi@example.com', 'phone' => '0911222333',
            'password' => 'matkhau', 'role' => 'admin', // cố nâng quyền
        ])->assertCreated()
            ->assertJsonPath('data.user.role', 'customer')
            ->assertJsonStructure(['data' => ['token']]);

        $this->assertSame('customer', User::where('email', 'moi@example.com')->first()->role->value);
    }

    public function test_logout_revokes_the_token(): void
    {
        $token = $this->postJson('/api/login', ['email' => 'customer@dineflow.com', 'password' => '123456'])->json('data.token');

        $this->withHeader('Authorization', "Bearer {$token}")->postJson('/api/logout')->assertOk();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    // ------------------------------------------------------------ Menu & bàn

    public function test_menu_filters_and_options(): void
    {
        $this->actAs('customer');

        $this->getJson('/api/categories')->assertOk()->assertJsonCount(6, 'data');

        $all = $this->getJson('/api/foods')->assertOk()->assertJsonCount(14, 'data');
        $this->assertNotEmpty(collect($all->json('data'))->firstWhere('name', 'Trà sữa trân châu')['options']);

        $this->getJson('/api/foods?search=trà')->assertOk()->assertJsonCount(3, 'data');
        $this->getJson('/api/foods?available=1')->assertOk()->assertJsonCount(13, 'data'); // Tiramisu hết hàng
    }

    public function test_tables_list_has_status_and_areas(): void
    {
        $this->actAs('staff');

        $this->getJson('/api/tables')->assertOk()
            ->assertJsonCount(12, 'data')
            ->assertJsonPath('meta.areas', ['Tầng 1', 'Tầng 2', 'Ngoài trời']) // thứ tự tạo bàn, không phải chữ cái
            ->assertJsonPath('data.0.number', 'Bàn 1');

        $this->getJson('/api/tables?area=Tầng 2&status=empty')->assertOk()
            ->assertJsonCount(3, 'data'); // Bàn 7, 9, 10 (Bàn 8 đang phục vụ; lượt đặt của Bàn 9 cách hơn 90 phút nên bàn vẫn trống)
    }

    // ------------------------------------------------------------ Đơn hàng

    public function test_staff_creates_order_with_server_side_prices_and_occupies_table(): void
    {
        $this->actAs('staff');
        $table = $this->table('Bàn 1');

        $this->postJson('/api/orders', ['table_id' => $table->id, 'items' => [$this->coffeeLine()]])
            ->assertCreated()
            ->assertJsonPath('data.subtotal', 74000)
            ->assertJsonPath('data.status', 'placed')
            ->assertJsonPath('data.items.0.unit_price', 37000)
            ->assertJsonPath('data.items.0.options_label', 'Size M');

        $table->refresh();
        $this->assertSame('serving', $table->status->value);
        $this->assertNotNull($table->current_order_id);
    }

    public function test_ordering_again_for_same_table_appends_to_the_open_order(): void
    {
        $this->actAs('staff');
        $table = $this->table('Bàn 1');

        $first = $this->postJson('/api/orders', ['table_id' => $table->id, 'items' => [$this->coffeeLine()]])->json('data.id');
        $this->postJson('/api/orders', ['table_id' => $table->id, 'items' => [$this->coffeeLine(1)]])
            ->assertOk()
            ->assertJsonPath('data.id', $first)
            ->assertJsonPath('data.subtotal', 111000)
            ->assertJsonCount(2, 'data.items');

        $this->assertDatabaseCount('orders', 11 + 1);
    }

    public function test_cannot_order_unavailable_food_or_without_a_table(): void
    {
        $this->actAs('staff');
        $tiramisu = Food::where('name', 'Tiramisu')->first();

        $this->postJson('/api/orders', ['table_id' => $this->table('Bàn 1')->id, 'items' => [['food_id' => $tiramisu->id, 'quantity' => 1]]])
            ->assertStatus(422);

        $this->postJson('/api/orders', ['items' => [$this->coffeeLine()]])->assertStatus(422)->assertJsonValidationErrors('table_id');
    }

    public function test_customer_only_sees_own_orders_and_cannot_pay(): void
    {
        $customer = $this->actAs('customer');

        $mine = collect($this->getJson('/api/orders')->assertOk()->json('data'));
        $this->assertTrue($mine->every(fn ($o) => $o['customer_id'] === $customer->id));

        $other = \App\Models\Order::where('customer_id', '!=', $customer->id)->orWhereNull('customer_id')->first();
        $this->getJson("/api/orders/{$other->id}")->assertStatus(403);
        $this->postJson("/api/orders/{$other->id}/pay", ['payment_method' => 'cash'])->assertStatus(403);
    }

    public function test_status_flow_is_enforced(): void
    {
        $this->actAs('staff');
        $id = $this->postJson('/api/orders', ['table_id' => $this->table('Bàn 1')->id, 'items' => [$this->coffeeLine()]])->json('data.id');

        $this->patchJson("/api/orders/{$id}/status", ['status' => 'preparing'])->assertOk()->assertJsonPath('data.status', 'preparing');
        $this->patchJson("/api/orders/{$id}/status", ['status' => 'placed'])->assertStatus(422); // không đi lùi
        $this->patchJson("/api/orders/{$id}/status", ['status' => 'bậy'])->assertStatus(422);
    }

    public function test_cancelling_an_order_frees_the_table(): void
    {
        $this->actAs('staff');
        $table = $this->table('Bàn 1');
        $id = $this->postJson('/api/orders', ['table_id' => $table->id, 'items' => [$this->coffeeLine()]])->json('data.id');

        // 13/11: không hủy qua đổi trạng thái nữa — phải qua chức năng Hủy đơn (Thu ngân / Admin) có lý do
        $this->patchJson("/api/orders/{$id}/status", ['status' => 'cancelled'])->assertStatus(422);

        $this->actAs('cashier');
        $this->patchJson("/api/orders/{$id}/cancel", ['reason' => 'wrong_entry'])->assertOk();

        $this->assertSame('empty', $table->fresh()->status->value);
        $this->patchJson("/api/orders/{$id}/status", ['status' => 'preparing'])->assertStatus(422); // đơn đã hủy bị khóa
    }

    // ------------------------------------------------------------ Thanh toán

    public function test_cashier_pays_with_promotion_and_table_is_released(): void
    {
        $this->actAs('staff');
        $table = $this->table('Bàn 1');
        $id = $this->postJson('/api/orders', ['table_id' => $table->id, 'items' => [$this->coffeeLine()]])->json('data.id');

        $this->actAs('staff');
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash'])->assertStatus(403); // nhân viên order không được thu tiền

        $this->actAs('cashier');
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'qr', 'promotion_code' => 'welcome10'])
            ->assertOk()
            ->assertJsonPath('data.subtotal', 74000)
            ->assertJsonPath('data.discount', 7400)
            ->assertJsonPath('data.total', 66600)
            ->assertJsonPath('data.payment_method', 'qr')
            ->assertJsonPath('data.promotion_code', 'WELCOME10')
            ->assertJsonPath('data.table_number', 'Bàn 1');

        $this->assertSame('empty', $table->fresh()->status->value);
        $this->assertNull($table->fresh()->current_order_id);
        $this->assertDatabaseHas('orders', ['id' => $id, 'payment_status' => 'paid', 'status' => 'completed']);

        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash'])->assertStatus(422); // không thu hai lần
        $this->assertDatabaseCount('invoices', 7 + 1);
    }

    public function test_invalid_or_ineligible_promotion_is_rejected_and_nothing_is_saved(): void
    {
        $this->actAs('staff');
        $id = $this->postJson('/api/orders', ['table_id' => $this->table('Bàn 1')->id, 'items' => [$this->coffeeLine()]])->json('data.id');

        $this->actAs('cashier');
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'promotion_code' => 'KHONGCO'])->assertStatus(422);
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'promotion_code' => 'TET2025'])->assertStatus(422); // hết hạn
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'promotion_code' => 'COMBO15'])->assertStatus(422); // chưa đủ 200.000đ

        $this->assertDatabaseHas('orders', ['id' => $id, 'payment_status' => 'unpaid']);
        $this->assertDatabaseCount('invoices', 7);
    }

    // ------------------------------------------------------------ Điểm thưởng & hóa đơn

    /** Khách (320 điểm) tự đặt 2 Cà phê sữa đá Size M = 74.000đ, trả về id đơn. */
    private function customerOrder(): int
    {
        $this->actAs('customer');

        return $this->postJson('/api/orders', ['items' => [$this->coffeeLine()]])->assertCreated()->json('data.id');
    }

    public function test_cashier_sees_customer_points_and_can_redeem_them(): void
    {
        $id = $this->customerOrder();

        $this->actAs('cashier');
        $this->getJson("/api/orders/{$id}")->assertJsonPath('data.customer_points', 320);

        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'promotion_code' => 'WELCOME10', 'points_used' => 300])
            ->assertOk()
            ->assertJsonPath('data.subtotal', 74000)
            ->assertJsonPath('data.discount', 7700) // 7.400 (10%) + 300 điểm
            ->assertJsonPath('data.total', 66300);

        $this->assertSame(20, User::where('email', 'customer@dineflow.com')->value('points'));
    }

    public function test_points_redemption_is_validated_and_failures_change_nothing(): void
    {
        $id = $this->customerOrder();
        $this->actAs('cashier');

        // Nhiều hơn số điểm đang có
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'points_used' => 321])
            ->assertStatus(422)->assertJsonValidationErrors('points_used');

        // Âm
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'points_used' => -5])
            ->assertStatus(422)->assertJsonValidationErrors('points_used');

        $this->assertSame(320, User::where('email', 'customer@dineflow.com')->value('points'));
        $this->assertDatabaseHas('orders', ['id' => $id, 'payment_status' => 'unpaid']);
        $this->assertDatabaseCount('invoices', 7);
    }

    public function test_points_cannot_be_used_on_orders_without_a_member(): void
    {
        $this->actAs('staff');
        $id = $this->postJson('/api/orders', ['table_id' => $this->table('Bàn 1')->id, 'items' => [$this->coffeeLine()]])->json('data.id');

        $this->actAs('cashier');
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'points_used' => 100])
            ->assertStatus(422)->assertJsonValidationErrors('points_used');

        // Không dùng điểm thì vẫn thanh toán bình thường
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'points_used' => 0])->assertOk();
    }

    public function test_points_cannot_exceed_the_amount_left_after_promotion(): void
    {
        // Đơn 74.000đ - WELCOME10 (7.400) = còn 66.600 -> 66.601 điểm là quá, dù khách có đủ điểm
        User::where('email', 'customer@dineflow.com')->update(['points' => 100000]);
        $id = $this->customerOrder();

        $this->actAs('cashier');
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'promotion_code' => 'WELCOME10', 'points_used' => 66601])
            ->assertStatus(422)->assertJsonValidationErrors('points_used');

        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash', 'promotion_code' => 'WELCOME10', 'points_used' => 66600])
            ->assertOk()->assertJsonPath('data.total', 0);
    }

    public function test_invoice_list_is_for_cashiers_and_admins_only(): void
    {
        $this->actAs('staff');
        $this->getJson('/api/invoices')->assertStatus(403);
        $this->actAs('customer');
        $this->getJson('/api/invoices')->assertStatus(403);

        $this->actAs('cashier');
        $res = $this->getJson('/api/invoices')->assertOk()->assertJsonCount(7, 'data')->assertJsonPath('meta.total', 7);

        $first = $res->json('data.0');
        $this->assertMatchesRegularExpression('/^HD\d{5}$/', $first['code']);
        $this->assertSame('paid', $first['status']);
        $this->assertNotEmpty($first['items']);
        $this->assertSame('Trần Thị Thu Ngân', $first['cashier_name']);

        // Mới nhất trước
        $times = collect($res->json('data'))->pluck('created_at')->all();
        $sorted = $times;
        rsort($sorted);
        $this->assertSame($sorted, $times);

        $this->actAs('admin');
        $this->getJson('/api/invoices')->assertOk();
    }

    public function test_invoice_list_filters_by_date_and_by_cashier(): void
    {
        $this->actAs('cashier');
        $today = now()->toDateString();

        $this->getJson("/api/invoices?date={$today}")->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/invoices?mine=1')->assertOk()->assertJsonCount(7, 'data'); // seed: toàn bộ do thu ngân này thu

        // Admin không phải người thu các hóa đơn mẫu
        $this->actAs('admin');
        $this->getJson('/api/invoices?mine=1')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_a_new_payment_shows_up_in_the_invoice_list(): void
    {
        $this->actAs('staff');
        $id = $this->postJson('/api/orders', ['table_id' => $this->table('Bàn 1')->id, 'items' => [$this->coffeeLine()]])->json('data.id');

        $this->actAs('cashier');
        $paid = $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'card'])->assertOk();

        $list = $this->getJson('/api/invoices')->assertOk()->assertJsonCount(8, 'data');
        $this->assertSame($paid->json('data.id'), $list->json('data.0.id'));
        $this->assertSame('card', $list->json('data.0.payment_method'));
    }

    // ------------------------------------------------------------ Báo cáo (admin)

    public function test_only_admin_can_read_the_report(): void
    {
        foreach (['staff', 'cashier', 'customer'] as $role) {
            $this->actAs($role);
            $this->getJson('/api/reports/overview')->assertStatus(403);
        }
    }

    public function test_report_overview_adds_up_the_paid_invoices(): void
    {
        $this->actAs('admin');
        $res = $this->getJson('/api/reports/overview')->assertOk();

        $invoices = Invoice::paid()->get();
        $todayTotal = (float) $invoices->filter(fn ($i) => $i->paid_at->isToday())->sum('total');

        $this->assertEqualsWithDelta($todayTotal, $res->json('data.today_revenue'), 0.01);
        $this->assertGreaterThan(0, $todayTotal);

        // 7 ngày / 6 tuần / 6 tháng, mốc mới nhất ở cuối
        $days = $res->json('data.revenue_by_day');
        $this->assertCount(7, $days);
        $this->assertCount(6, $res->json('data.revenue_by_week'));
        $this->assertCount(6, $res->json('data.revenue_by_month'));
        $this->assertEqualsWithDelta($todayTotal, end($days)['amount'], 0.01);
        $this->assertEqualsWithDelta($invoices->sum('total'), array_sum(array_column($days, 'amount')), 0.01); // seed: 7 hóa đơn trong 7 ngày
        $this->assertEqualsWithDelta($invoices->sum('total'), array_sum(array_column($res->json('data.revenue_by_month'), 'amount')), 0.01);
        $this->assertSame(['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][now()->dayOfWeekIso - 1], end($days)['label']);

        // Món bán chạy: giảm dần theo số lượng, chỉ tính đơn đã thanh toán (đơn đang phục vụ không vào)
        $top = $res->json('data.top_foods');
        $this->assertNotEmpty($top);
        $quantities = array_column($top, 'sold_quantity');
        $sorted = $quantities;
        rsort($sorted);
        $this->assertSame($sorted, $quantities);
        $this->assertSame(
            (int) OrderItem::whereHas('order', fn ($q) => $q->paid())->sum('quantity'),
            array_sum($quantities) // seed có ít hơn 10 món khác nhau được thanh toán
        );
        $this->assertSame(30, $res->json('data.top_foods_days'));
    }

    public function test_report_ignores_unpaid_orders_and_counts_todays_orders(): void
    {
        $this->actAs('admin');
        $before = $this->getJson('/api/reports/overview')->json('data');

        $this->actAs('staff');
        $id = $this->postJson('/api/orders', ['table_id' => $this->table('Bàn 1')->id, 'items' => [$this->coffeeLine()]])->json('data.id');

        $this->actAs('admin');
        $mid = $this->getJson('/api/reports/overview')->json('data');
        $this->assertSame($before['today_revenue'], $mid['today_revenue']); // chưa thanh toán thì chưa là doanh thu
        $this->assertSame($before['today_orders'] + 1, $mid['today_orders']);

        $this->actAs('cashier');
        $this->postJson("/api/orders/{$id}/pay", ['payment_method' => 'cash'])->assertOk();

        $this->actAs('admin');
        $after = $this->getJson('/api/reports/overview')->json('data');
        $this->assertEqualsWithDelta($before['today_revenue'] + 74000, $after['today_revenue'], 0.01);
        $this->assertEqualsWithDelta($before['week_revenue'] + 74000, $after['week_revenue'], 0.01);
    }

    public function test_report_revenue_range_sums_each_day_and_validates_input(): void
    {
        $this->actAs('admin');
        $from = now()->subDays(6)->toDateString();
        $to = now()->toDateString();

        $res = $this->getJson("/api/reports/revenue?from={$from}&to={$to}")->assertOk();
        $days = $res->json('data.revenue_by_day');
        $overviewDays = $this->getJson('/api/reports/overview')->json('data.revenue_by_day');

        $this->assertCount(7, $days);
        $this->assertSame(now()->format('d/m'), end($days)['label']);
        // Cùng 7 ngày gần nhất thì từng ngày phải khớp báo cáo tổng quan.
        $this->assertEqualsWithDelta(array_column($overviewDays, 'amount'), array_column($days, 'amount'), 0.01);
        $this->assertEqualsWithDelta(array_sum(array_column($days, 'amount')), $res->json('data.total'), 0.01);

        // Một ngày duy nhất
        $this->assertCount(1, $this->getJson("/api/reports/revenue?from={$to}&to={$to}")->assertOk()->json('data.revenue_by_day'));

        // Sai thứ tự, tương lai, quá 31 ngày, thiếu tham số
        $this->getJson("/api/reports/revenue?from={$to}&to={$from}")->assertStatus(422);
        $this->getJson('/api/reports/revenue?from=' . $to . '&to=' . now()->addDay()->toDateString())->assertStatus(422);
        $this->getJson('/api/reports/revenue?from=' . now()->subDays(31)->toDateString() . "&to={$to}")->assertStatus(422);
        $this->getJson('/api/reports/revenue')->assertStatus(422);

        foreach (['staff', 'cashier', 'customer'] as $role) {
            $this->actAs($role);
            $this->getJson("/api/reports/revenue?from={$from}&to={$to}")->assertStatus(403);
        }
    }

    // ------------------------------------------------------------ Giữ bàn (đặt bàn 3 bước qua app)

    /** Giữ bàn 11+12 ngày kia 19:00 cho 8 khách, chưa có món đặt trước. */
    private function holdPayload(array $override = []): array
    {
        return array_merge($this->reservationPayload(['pre_order_items' => null, 'pre_order_payment' => null]), ['hold' => true], $override);
    }

    public function test_hold_blocks_the_tables_then_confirm_with_pre_order_makes_it_permanent(): void
    {
        $this->actAs('customer');

        $held = $this->postJson('/api/reservations', $this->holdPayload())
            ->assertCreated()
            ->assertJsonPath('data.is_held', true)
            ->assertJsonPath('data.status', 'upcoming');
        $id = $held->json('data.id');
        $this->assertStringContainsString('giữ bàn', $held->json('message'));
        $this->assertEqualsWithDelta(
            now()->addMinutes(10)->timestamp,
            Carbon::parse($held->json('data.hold_expires_at'))->timestamp,
            5,
        );

        // Đang giữ thì người khác không đặt trùng được
        $this->postJson('/api/reservations', $this->holdPayload())->assertStatus(422)->assertJsonValidationErrors('table_ids');

        // Xác nhận kèm món đặt trước (Cơm sườn nướng x2 = 110.000)
        $rice = Food::where('name', 'Cơm sườn nướng')->value('id');
        $this->postJson("/api/reservations/{$id}/confirm", [
            'pre_order_items' => [['food_id' => $rice, 'quantity' => 2]],
            'pre_order_payment' => 'qr',
        ])->assertOk()
            ->assertJsonPath('data.is_held', false)
            ->assertJsonPath('data.hold_expires_at', null)
            ->assertJsonPath('data.pre_order_total', 110000)
            ->assertJsonPath('data.pre_order_payment', 'qr');

        // Gọi xác nhận lần nữa (vd. mất mạng rồi thử lại) không đổi gì và không báo lỗi
        $this->postJson("/api/reservations/{$id}/confirm", [])
            ->assertOk()->assertJsonPath('data.pre_order_total', 110000);

        // Vẫn chiếm bàn vì đã xác nhận
        $this->postJson('/api/reservations', $this->holdPayload())->assertStatus(422);
    }

    public function test_confirm_without_items_keeps_existing_pre_order_and_empty_array_clears_it(): void
    {
        $this->actAs('customer');

        $withItems = $this->postJson('/api/reservations', $this->holdPayload(['pre_order_items' => $this->reservationPayload()['pre_order_items'], 'pre_order_payment' => 'cash']))
            ->assertCreated()->json('data.id');
        $this->postJson("/api/reservations/{$withItems}/confirm", [])
            ->assertOk()->assertJsonPath('data.pre_order_total', 110000);

        $other = $this->postJson('/api/reservations', $this->holdPayload([
            'date_time' => now()->addDays(6)->setTime(19, 0)->toIso8601String(),
            'pre_order_items' => $this->reservationPayload()['pre_order_items'],
            'pre_order_payment' => 'cash',
        ]))->assertCreated()->json('data.id');
        $this->postJson("/api/reservations/{$other}/confirm", ['pre_order_items' => []])
            ->assertOk()->assertJsonPath('data.pre_order_total', 0)->assertJsonPath('data.pre_order_payment', null);
    }

    public function test_unconfirmed_hold_expires_and_releases_the_tables(): void
    {
        $this->actAs('customer');
        $id = $this->postJson('/api/reservations', $this->holdPayload())->assertCreated()->json('data.id');

        $this->travel(11)->minutes(); // khách tắt app, không xác nhận

        // Người khác đặt được đúng bàn, đúng giờ đó
        $this->postJson('/api/reservations', $this->holdPayload())->assertCreated();

        // Lượt cũ đã tự hủy, không xác nhận được nữa
        $this->assertDatabaseHas('reservations', ['id' => $id, 'status' => 'cancelled']);
        $this->postJson("/api/reservations/{$id}/confirm", [])
            ->assertStatus(422)->assertJsonPath('message', 'Lượt giữ bàn đã hết hạn hoặc đã bị hủy. Vui lòng đặt lại.');
    }

    public function test_cancelling_a_held_reservation_frees_the_tables_at_once(): void
    {
        $this->actAs('customer');
        $id = $this->postJson('/api/reservations', $this->holdPayload())->json('data.id');

        $this->patchJson("/api/reservations/{$id}/cancel")->assertOk()->assertJsonPath('data.status', 'cancelled');

        $this->postJson('/api/reservations', $this->holdPayload())->assertCreated();
        $this->postJson("/api/reservations/{$id}/confirm", [])->assertStatus(422);
    }

    public function test_only_the_owner_customer_can_confirm(): void
    {
        $this->actAs('customer');
        $id = $this->postJson('/api/reservations', $this->holdPayload())->json('data.id');

        $this->actAs('staff');
        $this->postJson("/api/reservations/{$id}/confirm", [])->assertStatus(403);

        Sanctum::actingAs(User::factory()->create(['role' => 'customer', 'status' => 'active']));
        $this->postJson("/api/reservations/{$id}/confirm", [])->assertStatus(403);
        $this->assertTrue(Reservation::find($id)->isHeld());
    }

    public function test_my_reservations_show_held_ones_but_not_lapsed_ones_as_upcoming(): void
    {
        $this->actAs('customer');
        $id = $this->postJson('/api/reservations', $this->holdPayload())->json('data.id');

        $mine = collect($this->getJson('/api/reservations/my')->json('data'))->firstWhere('id', $id);
        $this->assertTrue($mine['is_held']);
        $this->assertSame('upcoming', $mine['status']);

        $this->travel(11)->minutes();
        $mine = collect($this->getJson('/api/reservations/my')->json('data'))->firstWhere('id', $id);
        $this->assertSame('cancelled', $mine['status']);
    }

    public function test_held_table_is_reported_reserved_until_the_hold_lapses(): void
    {
        $this->actAs('customer');
        $table = $this->table('Bàn 11');
        $this->postJson('/api/reservations', $this->holdPayload([
            'table_ids' => [$table->id],
            'guest_count' => 2,
            'date_time' => now()->addMinutes(30)->toIso8601String(),
        ]))->assertCreated();

        $status = fn () => collect($this->getJson('/api/tables')->json('data'))->firstWhere('id', $table->id)['status'];

        $this->assertSame('reserved', $status());
        $this->travel(11)->minutes();
        $this->assertSame('empty', $status());
    }

    public function test_date_time_sent_in_utc_is_stored_in_the_restaurant_timezone(): void
    {
        $this->actAs('customer');
        $at = now()->addDays(4)->setTime(19, 0);

        $res = $this->postJson('/api/reservations', $this->holdPayload([
            'date_time' => $at->copy()->setTimezone('UTC')->format('Y-m-d\TH:i:s\Z'),
        ]))->assertCreated();

        $returned = Carbon::parse($res->json('data.date_time'));
        $this->assertSame('19:00', $returned->format('H:i')); // giờ ở quán, không bị lệch 7 tiếng
        $this->assertSame($at->toDateString(), $returned->toDateString());
    }

    // ------------------------------------------------------------ Đặt bàn

    private function reservationPayload(array $override = []): array
    {
        $rice = Food::where('name', 'Cơm sườn nướng')->first();

        return array_merge([
            'table_ids' => [$this->table('Bàn 11')->id, $this->table('Bàn 12')->id],
            'date_time' => now()->addDays(3)->setTime(19, 0)->toIso8601String(),
            'guest_count' => 8,
            'note' => 'Sinh nhật',
            'pre_order_items' => [['food_id' => $rice->id, 'quantity' => 2]],
            'pre_order_payment' => 'cash',
        ], $override);
    }

    public function test_customer_reserves_merged_tables_with_pre_order(): void
    {
        $this->actAs('customer');

        $res = $this->postJson('/api/reservations', $this->reservationPayload())
            ->assertCreated()
            ->assertJsonPath('data.status', 'upcoming')
            ->assertJsonPath('data.capacity', 10)
            ->assertJsonPath('data.table_numbers', ['Bàn 11', 'Bàn 12'])
            ->assertJsonPath('data.pre_order_total', 110000)
            ->assertJsonPath('data.pre_order_payment', 'cash');

        $this->assertMatchesRegularExpression('/^DF-\d{4}$/', $res->json('data.code'));

        $mine = $this->getJson('/api/reservations/my')->assertOk();
        $this->assertContains($res->json('data.id'), collect($mine->json('data'))->pluck('id')->all());
    }

    public function test_reservation_rules(): void
    {
        $this->actAs('customer');
        $t11 = $this->table('Bàn 11')->id;

        // 5 khách nhưng bàn chỉ có 4 chỗ
        $this->postJson('/api/reservations', $this->reservationPayload(['table_ids' => [$t11], 'guest_count' => 5, 'pre_order_items' => null]))
            ->assertStatus(422)->assertJsonValidationErrors('guest_count');

        // ghép bàn khác khu vực
        $this->postJson('/api/reservations', $this->reservationPayload(['table_ids' => [$t11, $this->table('Bàn 1')->id]]))
            ->assertStatus(422)->assertJsonValidationErrors('table_ids');

        // quá khứ
        $this->postJson('/api/reservations', $this->reservationPayload(['date_time' => now()->subDay()->toIso8601String()]))
            ->assertStatus(422)->assertJsonValidationErrors('date_time');

        // trùng giờ
        $this->postJson('/api/reservations', $this->reservationPayload())->assertCreated();
        $this->postJson('/api/reservations', $this->reservationPayload(['table_ids' => [$t11], 'guest_count' => 2, 'date_time' => now()->addDays(3)->setTime(20, 0)->toIso8601String(), 'pre_order_items' => null]))
            ->assertStatus(422)->assertJsonValidationErrors('table_ids');

        // khác giờ (cách > 2 tiếng) thì được
        $this->postJson('/api/reservations', $this->reservationPayload(['table_ids' => [$t11], 'guest_count' => 2, 'date_time' => now()->addDays(3)->setTime(22, 30)->toIso8601String(), 'pre_order_items' => null]))
            ->assertCreated();

        // chỉ khách hàng mới được đặt bàn
        $this->actAs('staff');
        $this->postJson('/api/reservations', $this->reservationPayload())->assertStatus(403);
    }

    public function test_customer_can_cancel_only_own_upcoming_reservation(): void
    {
        $this->actAs('customer');
        $id = $this->postJson('/api/reservations', $this->reservationPayload())->json('data.id');

        $this->patchJson("/api/reservations/{$id}/cancel")->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->patchJson("/api/reservations/{$id}/cancel")->assertStatus(422); // đã hủy rồi

        // Khách khác không hủy được lượt đặt của người ta
        $newId = $this->postJson('/api/reservations', $this->reservationPayload(['date_time' => now()->addDays(5)->setTime(19, 0)->toIso8601String()]))->json('data.id');
        Sanctum::actingAs(User::factory()->create(['role' => 'customer', 'status' => 'active']));
        $this->patchJson("/api/reservations/{$newId}/cancel")->assertStatus(403);
        $this->assertSame('upcoming', Reservation::find($newId)->status->value);
    }

    // ------------------------------------------------------------ Nhận bàn, tự hủy khi trễ, khách vãng lai

    /** Khách giữ Bàn 11 + 12 lúc $minutes phút nữa rồi xác nhận kèm Cơm sườn nướng x2 (110.000, cọc 55.000). */
    private function confirmedReservationWithDeposit(int $minutes): int
    {
        $this->actAs('customer');
        $id = $this->postJson('/api/reservations', $this->holdPayload([
            'date_time' => now()->addMinutes($minutes)->toIso8601String(),
        ]))->assertCreated()->json('data.id');

        $rice = Food::where('name', 'Cơm sườn nướng')->value('id');
        $this->postJson("/api/reservations/{$id}/confirm", [
            'pre_order_items' => [['food_id' => $rice, 'quantity' => 2]],
            'pre_order_payment' => 'qr',
        ])->assertOk()->assertJsonPath('data.deposit_amount', 55000);

        return $id;
    }

    public function test_check_in_creates_order_from_pre_order_and_payment_deducts_deposit(): void
    {
        $id = $this->confirmedReservationWithDeposit(20);
        $date = Reservation::find($id)->date_time->toDateString();

        // Phân quyền: khách không xem lịch đặt của quán; admin xem được nhưng không nhận bàn
        $this->getJson("/api/reservations?date={$date}")->assertStatus(403);
        $this->actAs('admin');
        $this->getJson("/api/reservations?date={$date}")->assertOk();
        $this->postJson("/api/reservations/{$id}/check-in")->assertStatus(403);

        // NV Order thấy lượt đặt kèm tên khách rồi nhận bàn
        $this->actAs('staff');
        $row = collect($this->getJson("/api/reservations?date={$date}")->assertOk()->json('data'))->firstWhere('id', $id);
        $this->assertSame('Lê Minh Khách', $row['customer_name']);

        $res = $this->postJson("/api/reservations/{$id}/check-in")
            ->assertCreated()
            ->assertJsonPath('data.reservation.status', 'completed')
            ->assertJsonPath('data.order.reservation_id', $id)
            ->assertJsonPath('data.order.subtotal', 110000)
            ->assertJsonPath('data.order.deposit_amount', 55000);
        $orderId = $res->json('data.order.id');

        // Cả hai bàn ghép cùng trỏ tới một đơn
        foreach (['Bàn 11', 'Bàn 12'] as $number) {
            $this->assertSame('serving', $this->table($number)->status->value);
            $this->assertEquals($orderId, $this->table($number)->current_order_id);
        }

        // Bấm lại không tạo đơn thứ hai
        $this->postJson("/api/reservations/{$id}/check-in")->assertStatus(422);

        // Thu ngân thanh toán: trừ cọc 55.000, trả cả hai bàn
        $this->actAs('cashier');
        $this->postJson('/api/shifts', ['opening_cash' => 500000])->assertCreated();
        $this->postJson("/api/orders/{$orderId}/pay", ['payment_method' => 'cash'])
            ->assertOk()
            ->assertJsonPath('data.subtotal', 110000)
            ->assertJsonPath('data.deposit_amount', 55000)
            ->assertJsonPath('data.total', 55000);

        foreach (['Bàn 11', 'Bàn 12'] as $number) {
            $this->assertSame('empty', $this->table($number)->status->value);
            $this->assertNull($this->table($number)->current_order_id);
        }
    }

    public function test_check_in_is_only_open_from_30_minutes_before_until_15_minutes_after(): void
    {
        $id = $this->confirmedReservationWithDeposit(120);
        $this->actAs('staff');

        // Sớm hơn 30 phút: chưa nhận được
        $this->postJson("/api/reservations/{$id}/check-in")->assertStatus(422);

        // Còn 25 phút nữa tới giờ hẹn: nhận được
        $this->travel(95)->minutes();
        $this->postJson("/api/reservations/{$id}/check-in")->assertCreated();
    }

    public function test_reservation_is_cancelled_when_customer_is_more_than_15_minutes_late(): void
    {
        $id = $this->confirmedReservationWithDeposit(20);
        $t11 = $this->table('Bàn 11')->id;

        // 20 + 16 phút: trễ 16 phút
        $this->travel(36)->minutes();
        $this->actAs('staff');

        $status = collect($this->getJson('/api/tables')->assertOk()->json('data'))->firstWhere('id', $t11)['status'];
        $this->assertSame('empty', $status);

        $reservation = Reservation::find($id);
        $this->assertSame('cancelled', $reservation->status->value);
        $this->assertEquals(55000, (float) $reservation->deposit_amount); // cọc giữ lại, không hoàn
        $this->assertDatabaseHas('notifications', [
            'customer_id' => $reservation->customer_id,
            'title' => 'Lượt đặt bàn bị hủy do quá giờ',
        ]);
        $this->assertSame(1, \App\Models\AppNotification::where('title', 'Lượt đặt bàn bị hủy do quá giờ')->count()); // không gửi trùng

        $this->postJson("/api/reservations/{$id}/check-in")->assertStatus(422);

        // Bàn đã trống: nhận khách vãng lai được
        $this->postJson('/api/orders', ['table_id' => $t11, 'items' => [$this->coffeeLine()]])->assertCreated();
    }

    public function test_walk_in_cannot_take_a_table_held_for_a_reservation(): void
    {
        $this->confirmedReservationWithDeposit(60);
        $this->actAs('staff');

        // Bàn 11 có khách đặt trong 60 phút tới → không mở cho khách vãng lai
        $this->postJson('/api/orders', ['table_id' => $this->table('Bàn 11')->id, 'items' => [$this->coffeeLine()]])
            ->assertStatus(422)->assertJsonValidationErrors('table_id');

        // Cũng không chuyển khách đang ngồi sang bàn đó
        $this->postJson('/api/orders', ['table_id' => $this->table('Bàn 1')->id, 'items' => [$this->coffeeLine()]])->assertCreated();
        $this->postJson("/api/tables/{$this->table('Bàn 1')->id}/transfer", ['to_table_id' => $this->table('Bàn 11')->id])
            ->assertStatus(422);
        $this->assertSame('serving', $this->table('Bàn 1')->status->value);
    }

    public function test_serving_table_is_only_blocked_for_bookings_within_90_minutes(): void
    {
        $this->actAs('staff');
        $t1 = $this->table('Bàn 1')->id;
        $this->postJson('/api/orders', ['table_id' => $t1, 'items' => [$this->coffeeLine()]])->assertCreated();

        $this->actAs('customer');
        $soon = now()->addMinutes(60)->toIso8601String();
        $later = now()->addHours(3)->toIso8601String();
        $available = fn (string $at) => collect($this->getJson('/api/tables/available?datetime='.urlencode($at))->assertOk()->json('data'))
            ->firstWhere('id', $t1)['available'];

        $this->assertFalse($available($soon));
        $this->assertTrue($available($later));

        $payload = fn (string $at) => $this->reservationPayload(['table_ids' => [$t1], 'guest_count' => 2, 'date_time' => $at, 'pre_order_items' => null, 'pre_order_payment' => null]);
        $this->postJson('/api/reservations', $payload($soon))->assertStatus(422)->assertJsonValidationErrors('table_ids');
        $this->postJson('/api/reservations', $payload($later))->assertCreated();
    }

    public function test_staff_can_cancel_a_reservation_and_the_deposit_is_kept(): void
    {
        $id = $this->confirmedReservationWithDeposit(60 * 24 * 3);

        $this->actAs('cashier');
        $message = $this->patchJson("/api/reservations/{$id}/cancel")
            ->assertOk()->assertJsonPath('data.status', 'cancelled')->json('message');
        $this->assertStringContainsString('không được hoàn lại', $message);
        $this->assertEquals(55000, (float) Reservation::find($id)->deposit_amount);

        // Hủy xong bàn đặt lại được ngay ở giờ đó
        $this->actAs('customer');
        $this->postJson('/api/reservations', $this->holdPayload([
            'date_time' => Reservation::find($id)->date_time->toIso8601String(),
        ]))->assertCreated();
    }
}
