<?php

namespace Database\Seeders;

use App\Enums\InvoiceStatus;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethod;
use App\Enums\PaymentStatus;
use App\Enums\ReservationStatus;
use App\Enums\TableStatus;
use App\Enums\UserRole;
use App\Enums\UserStatus;
use App\Models\Category;
use App\Models\DiningTable;
use App\Models\Food;
use App\Models\FoodOption;
use App\Models\Invoice;
use App\Models\Order;
use App\Models\Promotion;
use App\Models\Reservation;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Storage;

/**
 * Dữ liệu mẫu khớp mock data của app Flutter (lib/data/mock_data.dart, assets/data/foods.json).
 * Mật khẩu mọi tài khoản mẫu: 123456
 */
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $users = $this->seedUsers();
        $categories = $this->seedCategories();
        $foods = $this->seedFoods($categories);
        $tables = $this->seedTables();
        $this->seedPromotions();
        $this->seedOrders($users, $foods, $tables);
        $this->seedReservations($users, $foods, $tables);
    }

    /** @return array<string, User> */
    private function seedUsers(): array
    {
        $rows = [
            'admin' => ['name' => 'Quản trị viên', 'email' => 'admin@dineflow.com', 'phone' => '0900000001', 'role' => UserRole::Admin],
            'staff' => ['name' => 'Nguyễn Văn Order', 'email' => 'staff@dineflow.com', 'phone' => '0900000002', 'role' => UserRole::OrderStaff],
            'cashier' => ['name' => 'Trần Thị Thu Ngân', 'email' => 'cashier@dineflow.com', 'phone' => '0900000003', 'role' => UserRole::Cashier],
            'customer' => ['name' => 'Lê Minh Khách', 'email' => 'customer@dineflow.com', 'phone' => '0900000004', 'role' => UserRole::Customer, 'member_code' => 'DF-MB0001', 'points' => 320],
            'locked' => ['name' => 'Phạm Bị Khóa', 'email' => 'locked@dineflow.com', 'phone' => '0900000005', 'role' => UserRole::OrderStaff, 'status' => UserStatus::Locked],
        ];

        $result = [];
        foreach ($rows as $key => $data) {
            $result[$key] = User::updateOrCreate(
                ['email' => $data['email']],
                $data + ['password' => '123456', 'status' => UserStatus::Active],
            );
        }

        return $result;
    }

    /** @return array<string, Category> keyed theo id danh mục bên Flutter (c1..c6) */
    private function seedCategories(): array
    {
        $rows = [
            'c1' => ['Cà phê', 'coffee'],
            'c2' => ['Trà', 'emoji_food_beverage'],
            'c3' => ['Nước ép', 'local_bar'],
            'c4' => ['Món chính', 'restaurant'],
            'c5' => ['Khai vị', 'tapas'],
            'c6' => ['Tráng miệng', 'icecream'],
        ];

        $result = [];
        $order = 0;
        foreach ($rows as $key => [$name, $icon]) {
            $result[$key] = Category::updateOrCreate(['name' => $name], ['icon' => $icon, 'sort_order' => $order++]);
        }

        return $result;
    }

    /** @return array<string, Food> keyed theo id món bên Flutter (f1..f14) */
    private function seedFoods(array $categories): array
    {
        $sizes = [['Size S', 0], ['Size M', 8000], ['Size L', 14000]];
        $toppings = [['Trân châu', 6000], ['Pudding', 7000], ['Kem cheese', 10000]];

        // key => [category, name, price, description, icon, color, rating, bestSeller, available, optionGroups]
        $rows = [
            'f1' => ['c1', 'Cà phê sữa đá', 29000, 'Cà phê phin truyền thống pha cùng sữa đặc, đá viên mát lạnh.', 'coffee', '#8B5A2B', 4.8, true, true, ['size']],
            'f2' => ['c1', 'Bạc xỉu', 32000, 'Vị cà phê nhẹ nhàng hòa quyện cùng sữa tươi béo ngậy.', 'coffee', '#B08968', 4.6, false, true, ['size']],
            'f3' => ['c1', 'Espresso', 35000, 'Cà phê nguyên chất đậm đà, chiết xuất từ máy espresso.', 'local_cafe', '#5C3A21', 4.4, false, true, []],
            'f4' => ['c2', 'Trà đào cam sả', 39000, 'Trà đào thơm mát kết hợp cam tươi và sả.', 'emoji_food_beverage', '#E8A22C', 4.7, true, true, ['size', 'topping']],
            'f5' => ['c2', 'Trà sữa trân châu', 35000, 'Trà sữa béo thơm cùng trân châu đường đen dẻo dai.', 'emoji_food_beverage', '#C08552', 4.9, true, true, ['size', 'topping']],
            'f6' => ['c2', 'Trà chanh', 25000, 'Trà chanh mật ong giải khát, chua ngọt hài hòa.', 'emoji_food_beverage', '#A8C66C', 4.3, false, true, []],
            'f7' => ['c3', 'Nước ép cam', 35000, 'Cam tươi ép nguyên chất, giàu vitamin C.', 'local_bar', '#F2994A', 4.5, false, true, []],
            'f8' => ['c3', 'Sinh tố bơ', 42000, 'Bơ sáp xay cùng sữa đặc, sánh mịn béo ngậy.', 'local_bar', '#6B8E23', 4.6, false, true, []],
            'f9' => ['c4', 'Cơm sườn nướng', 55000, 'Cơm tấm sườn nướng mật ong ăn kèm đồ chua, trứng ốp la.', 'rice_bowl', '#D8433D', 4.7, true, true, []],
            'f10' => ['c4', 'Mì Ý sốt bò bằm', 65000, 'Mì Ý sốt cà chua bò bằm đậm đà, phô mai bào.', 'dinner_dining', '#C94D1C', 4.5, false, true, []],
            'f11' => ['c5', 'Khoai tây chiên', 32000, 'Khoai tây chiên giòn rụm, ăn kèm sốt phô mai.', 'tapas', '#E8A22C', 4.4, false, true, []],
            'f12' => ['c5', 'Gà cánh chiên nước mắm', 48000, 'Cánh gà chiên giòn áo sốt nước mắm tỏi ớt.', 'tapas', '#E8622C', 4.8, true, true, []],
            'f13' => ['c6', 'Bánh flan', 22000, 'Bánh flan caramel mềm mịn, thơm vị trứng sữa.', 'icecream', '#F2C94C', 4.6, false, true, []],
            'f14' => ['c6', 'Tiramisu', 38000, 'Bánh tiramisu vị cà phê nguyên bản kiểu Ý.', 'icecream', '#6B4423', 4.7, false, false, []],
        ];

        // Tên file ảnh (database/seeders/images/foods/<tên>.jpg), ảnh gốc lấy từ app Flutter rồi nén còn 800px
        $images = [
            'f1' => 'ca_phe_sua_da', 'f2' => 'bac_xiu', 'f3' => 'espresso', 'f4' => 'tra_dao_cam_sa',
            'f5' => 'tra_sua_tran_chau', 'f6' => 'tra_chanh', 'f7' => 'nuoc_cam', 'f8' => 'sinh_to_bo',
            'f9' => 'com_suon_nuong', 'f10' => 'mi_y_sot_bo_bam', 'f11' => 'khoai_tay_chien',
            'f12' => 'ga_canh_chien_nuoc_mam', 'f13' => 'banh_flan', 'f14' => 'tiramisu',
        ];

        $result = [];
        foreach ($rows as $key => [$cat, $name, $price, $desc, $icon, $color, $rating, $best, $available, $groups]) {
            $food = Food::updateOrCreate(['name' => $name], [
                'category_id' => $categories[$cat]->id,
                'price' => $price,
                'description' => $desc,
                'image' => $this->storeFoodImage($images[$key] ?? null),
                'icon' => $icon,
                'color' => $color,
                'rating' => $rating,
                'is_best_seller' => $best,
                'is_available' => $available,
            ]);

            $food->options()->delete();
            foreach ($groups as $group) {
                foreach ($group === 'size' ? $sizes : $toppings as [$optName, $extra]) {
                    FoodOption::create(['food_id' => $food->id, 'name' => $optName, 'group' => $group, 'price_modifier' => $extra]);
                }
            }

            $result[$key] = $food->load('options');
        }

        return $result;
    }

    /** Sao chép ảnh mẫu vào kho ảnh công khai (storage/app/public/foods), trả về đường dẫn lưu trong DB. */
    private function storeFoodImage(?string $file): ?string
    {
        $source = database_path("seeders/images/foods/{$file}.jpg");

        if ($file === null || ! is_file($source)) {
            return null;
        }

        Storage::disk('public')->put("foods/{$file}.jpg", file_get_contents($source));

        return "foods/{$file}.jpg";
    }

    /** @return array<int, DiningTable> keyed theo số bàn */
    private function seedTables(): array
    {
        // số bàn => [khu vực, sức chứa]
        $rows = [
            1 => ['Tầng 1', 4], 2 => ['Tầng 1', 4], 3 => ['Tầng 1', 6], 4 => ['Tầng 1', 4], 5 => ['Tầng 1', 4], 6 => ['Tầng 1', 4],
            7 => ['Tầng 2', 4], 8 => ['Tầng 2', 4], 9 => ['Tầng 2', 2], 10 => ['Tầng 2', 4],
            11 => ['Ngoài trời', 4], 12 => ['Ngoài trời', 6],
        ];

        $result = [];
        foreach ($rows as $n => [$area, $capacity]) {
            $result[$n] = DiningTable::updateOrCreate(['number' => "Bàn {$n}"], [
                'area' => $area,
                'capacity' => $capacity,
                'status' => TableStatus::Empty,
                'serving_since' => null,
                'current_order_id' => null,
            ]);
        }

        return $result;
    }

    private function seedPromotions(): void
    {
        $rows = [
            ['WELCOME10', 'Chào bạn mới', 'Giảm 10% cho đơn đầu tiên.', 10, 30000, 0, now()->subMonth(), now()->addMonths(3)],
            ['COMBO15', 'Combo bạn bè', 'Giảm 15% cho đơn từ 200.000đ.', 15, 50000, 200000, now()->subWeek(), now()->addMonth()],
            ['SUMMER20', 'Hè rực rỡ', 'Giảm 20% mùa hè, tối đa 60.000đ.', 20, 60000, 100000, now()->addWeek(), now()->addMonths(2)],
            ['TET2025', 'Khuyến mãi cũ', 'Chương trình đã kết thúc.', 25, 80000, 0, now()->subMonths(8), now()->subMonths(6)],
        ];

        foreach ($rows as [$code, $title, $desc, $percent, $max, $min, $from, $to]) {
            Promotion::updateOrCreate(['code' => $code], [
                'title' => $title,
                'description' => $desc,
                'discount_percent' => $percent,
                'max_discount' => $max,
                'min_order_amount' => $min,
                'valid_from' => $from,
                'valid_to' => $to,
                'is_active' => true,
            ]);
        }
    }

    /**
     * Tạo đơn kèm món. $lines = [[foodKey, quantity, [tên option...], note?], ...]
     * Dùng forceFill để đặt được created_at (không nằm trong $fillable).
     */
    private function makeOrder(array $attrs, array $lines, array $foods): Order
    {
        $order = (new Order)->forceFill($attrs);
        $order->save();

        foreach ($lines as $line) {
            [$key, $qty, $optionNames] = $line;
            $food = $foods[$key];

            $order->items()->create([
                'food_id' => $food->id,
                'food_name' => $food->name,
                'quantity' => $qty,
                'options' => $food->options->whereIn('name', $optionNames)->map->toSnapshot()->values()->all(),
                'price' => $food->price,
                'note' => $line[3] ?? null,
            ]);
        }

        return $order->recalculateTotal();
    }

    private function seedOrders(array $users, array $foods, array $tables): void
    {
        // Seeder chạy lại được: xóa đơn cũ rồi tạo lại.
        Invoice::query()->delete();
        DiningTable::query()->update(['current_order_id' => null]);
        Order::query()->delete();

        // 1) Bàn 2 đang phục vụ, chưa thanh toán
        $o1 = $this->makeOrder([
            'table_id' => $tables[2]->id, 'staff_id' => $users['staff']->id,
            'status' => OrderStatus::Serving, 'payment_status' => PaymentStatus::Unpaid,
            'created_at' => now()->subMinutes(45),
        ], [['f1', 2, ['Size M']], ['f12', 1, []], ['f11', 1, []]], $foods);
        $tables[2]->update(['status' => TableStatus::Serving, 'serving_since' => now()->subMinutes(45), 'current_order_id' => $o1->id]);

        // 2) Bàn 5 vừa gọi món, đang chuẩn bị
        $o2 = $this->makeOrder([
            'table_id' => $tables[5]->id, 'staff_id' => $users['staff']->id,
            'status' => OrderStatus::Preparing, 'payment_status' => PaymentStatus::Unpaid,
            'note' => 'Ít đá', 'created_at' => now()->subMinutes(10),
        ], [['f5', 2, ['Size L', 'Trân châu']], ['f9', 2, [], 'Không hành']], $foods);
        $tables[5]->update(['status' => TableStatus::Serving, 'serving_since' => now()->subMinutes(10), 'current_order_id' => $o2->id]);

        // 3) Bàn 8 vừa đặt, chờ bếp
        $o3 = $this->makeOrder([
            'table_id' => $tables[8]->id, 'staff_id' => $users['staff']->id,
            'status' => OrderStatus::Placed, 'payment_status' => PaymentStatus::Unpaid,
            'created_at' => now()->subMinutes(2),
        ], [['f10', 1, []], ['f7', 1, []]], $foods);
        $tables[8]->update(['status' => TableStatus::Serving, 'serving_since' => now()->subMinutes(2), 'current_order_id' => $o3->id]);

        // 4) Khách tự đặt (không gắn bàn), chờ xác nhận thanh toán
        $this->makeOrder([
            'customer_id' => $users['customer']->id,
            'status' => OrderStatus::Placed, 'payment_status' => PaymentStatus::Pending,
            'created_at' => now()->subMinutes(5),
        ], [['f4', 1, ['Size M', 'Pudding']]], $foods);

        // Đơn đã thanh toán trong 7 ngày gần nhất (hôm nay + 6 ngày trước) -> dữ liệu cho dashboard
        $paidPlans = [
            0 => [['f1', 2, ['Size M']], ['f9', 1, []]],
            1 => [['f5', 3, ['Size L']], ['f12', 2, []], ['f13', 2, []]],
            2 => [['f9', 4, []], ['f10', 2, []]],
            3 => [['f4', 2, ['Size M', 'Trân châu']], ['f11', 2, []]],
            4 => [['f1', 5, ['Size S']], ['f8', 2, []]],
            5 => [['f10', 3, []], ['f12', 3, []], ['f7', 3, []]],
            6 => [['f9', 2, []], ['f5', 2, ['Size M']]],
        ];
        $methods = [PaymentMethod::Cash, PaymentMethod::Qr, PaymentMethod::Card];

        foreach ($paidPlans as $daysAgo => $lines) {
            $paidAt = now()->subDays($daysAgo)->setTime(12, 30);
            if ($paidAt->isFuture()) {
                $paidAt = now()->subMinutes(1);
            }

            $order = $this->makeOrder([
                'table_id' => $tables[($daysAgo % 6) + 1]->id,
                'staff_id' => $users['staff']->id,
                'status' => OrderStatus::Completed,
                'payment_status' => PaymentStatus::Paid,
                'created_at' => $paidAt->copy()->subMinutes(50),
            ], $lines, $foods);

            Invoice::create([
                'order_id' => $order->id,
                'cashier_id' => $users['cashier']->id,
                'subtotal' => $order->total_amount,
                'discount' => 0,
                'total' => $order->total_amount,
                'payment_method' => $methods[$daysAgo % 3],
                'status' => InvoiceStatus::Paid,
                'paid_at' => $paidAt,
            ]);
        }
    }

    private function seedReservations(array $users, array $foods, array $tables): void
    {
        Reservation::query()->delete();

        // Sắp tới: ghép Bàn 3 + Bàn 4 (Tầng 1), có đặt món trước
        Reservation::create([
            'customer_id' => $users['customer']->id,
            'table_ids' => [$tables[3]->id, $tables[4]->id],
            'area' => 'Tầng 1',
            'date_time' => now()->addDay()->setTime(19, 0),
            'guest_count' => 8,
            'note' => 'Sinh nhật bạn, cần bàn gần cửa sổ.',
            'status' => ReservationStatus::Upcoming,
            'pre_order_payment' => PaymentMethod::Cash,
            'pre_order_items' => [
                $this->preOrderLine($foods['f9'], 4),
                $this->preOrderLine($foods['f13'], 2),
            ],
        ]);
        $tables[3]->update(['status' => TableStatus::Reserved]);
        $tables[4]->update(['status' => TableStatus::Reserved]);

        // Sắp tới trong vài giờ: Bàn 9
        Reservation::create([
            'customer_id' => $users['customer']->id,
            'table_ids' => [$tables[9]->id],
            'area' => 'Tầng 2',
            'date_time' => now()->addHours(3),
            'guest_count' => 2,
            'status' => ReservationStatus::Upcoming,
        ]);
        $tables[9]->update(['status' => TableStatus::Reserved]);

        // Đã hoàn thành và đã hủy
        Reservation::create([
            'customer_id' => $users['customer']->id,
            'table_ids' => [$tables[7]->id],
            'area' => 'Tầng 2',
            'date_time' => now()->subDays(5)->setTime(18, 30),
            'guest_count' => 3,
            'status' => ReservationStatus::Completed,
        ]);
        Reservation::create([
            'customer_id' => $users['customer']->id,
            'table_ids' => [$tables[10]->id],
            'area' => 'Tầng 2',
            'date_time' => now()->subDays(2)->setTime(20, 0),
            'guest_count' => 2,
            'note' => 'Khách báo bận.',
            'status' => ReservationStatus::Cancelled,
        ]);
    }

    private function preOrderLine(Food $food, int $quantity, array $optionNames = []): array
    {
        return [
            'food_id' => $food->id,
            'food_name' => $food->name,
            'quantity' => $quantity,
            'price' => (float) $food->price,
            'options' => $food->options->whereIn('name', $optionNames)->map->toSnapshot()->values()->all(),
            'note' => null,
        ];
    }
}
