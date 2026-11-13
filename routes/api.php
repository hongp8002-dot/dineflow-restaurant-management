<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CancelOrderController;
use App\Http\Controllers\Api\FavoriteController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\CheckoutController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\MemberController;
use App\Http\Controllers\Api\MenuController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PasswordResetController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ReportExportController;
use App\Http\Controllers\Api\ReservationController;
use App\Http\Controllers\Api\ShiftController;
use App\Http\Controllers\Api\SettingsController;
use App\Http\Controllers\Api\TableController;
use App\Http\Controllers\Api\TableOperationController;
use App\Http\Controllers\Api\Admin\CategoryAdminController;
use App\Http\Controllers\Api\Admin\FoodAdminController;
use App\Http\Controllers\Api\Admin\PromotionAdminController;
use App\Http\Controllers\Api\Admin\TableAdminController;
use App\Http\Controllers\Api\Admin\UserAdminController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| DineFlow REST API  (tiền tố /api)
|--------------------------------------------------------------------------
| Phản hồi luôn có dạng { status: "success"|"error", message, data }.
| Các route ngoài login/register cần header:  Authorization: Bearer <token>
*/

// Công khai (giới hạn 10 lần/phút chống dò mật khẩu)
Route::middleware('throttle:10,1')->group(function () {
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/register', [AuthController::class, 'register']);

    // Quên mật khẩu bằng mã OTP qua email (chỉ khách hàng)
    Route::post('/password/forgot', [PasswordResetController::class, 'forgot']);
    Route::post('/password/verify', [PasswordResetController::class, 'verify']);
    Route::post('/password/reset', [PasswordResetController::class, 'reset']);
});

// Tải file Excel bằng link có chữ ký (app Admin xin link qua POST /reports/export-link, hết hạn 5 phút)
Route::get('/reports/export/download', [ReportExportController::class, 'download'])
    ->middleware('signed')
    ->name('reports.export.download');

// Cần đăng nhập và tài khoản không bị khóa
Route::middleware(['auth:sanctum', 'active'])->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::patch('/me/password', [AuthController::class, 'changePassword']);

    // Cấu hình dùng chung: tài khoản nhận chuyển khoản, quy tắc thành viên (mọi vai trò)
    Route::get('/settings', [SettingsController::class, 'show']);

    // Thực đơn, bàn, khuyến mãi: mọi vai trò đều xem được
    Route::get('/categories', [MenuController::class, 'categories']);
    Route::get('/foods', [MenuController::class, 'foods']);
    Route::get('/promotions', [MenuController::class, 'promotions']);
    // QUAN TRỌNG: /tables/available phải đăng ký TRƯỚC /tables
    // để Laravel không hiểu "available" là {table} ID.
    Route::get('/tables/available', [TableController::class, 'available']);
    Route::get('/tables', [TableController::class, 'index']);

    // Đặt bàn (khách hàng)
    // QUAN TRỌNG: /reservations/my phải đứng trước các route có {reservation}.
    Route::get('/reservations/my', [ReservationController::class, 'my']);
    Route::post('/reservations', [ReservationController::class, 'store'])->middleware('role:customer');
    Route::post('/reservations/{reservation}/confirm', [ReservationController::class, 'confirm'])->middleware('role:customer');
    // Hủy: khách hủy lượt của mình; NV Order / Thu ngân / Admin hủy mọi lượt (kiểm tra trong controller)
    Route::patch('/reservations/{reservation}/cancel', [ReservationController::class, 'cancel']);

    // Lịch đặt bàn của nhà hàng (NV Order, Thu ngân, Admin) và nhận bàn khi khách tới (NV Order, Thu ngân)
    Route::get('/reservations', [ReservationController::class, 'index'])->middleware('role:order_staff,cashier,admin');
    Route::post('/reservations/{reservation}/check-in', [ReservationController::class, 'checkIn'])->middleware('role:order_staff,cashier');

    // Đơn hàng
    Route::get('/orders', [OrderController::class, 'index']);
    Route::post('/orders', [OrderController::class, 'store'])->middleware('role:order_staff,admin,customer');
    Route::get('/orders/{order}', [OrderController::class, 'show']);
    Route::patch('/orders/{order}/status', [OrderController::class, 'updateStatus'])->middleware('role:order_staff,cashier,admin');

    // Hủy đơn (Thu ngân + Admin)
    Route::patch('/orders/{order}/cancel', [CancelOrderController::class, 'cancel'])->middleware('role:cashier,admin');

    // Thanh toán (thu ngân)
    Route::post('/orders/{order}/pay', [CheckoutController::class, 'pay'])->middleware('role:cashier,admin');
    Route::get('/invoices', [InvoiceController::class, 'index'])->middleware('role:cashier,admin');

    // Ca làm (thu ngân)
    Route::middleware('role:cashier,admin')->group(function () {
        Route::get('/shifts/current', [ShiftController::class, 'current']);
        Route::post('/shifts', [ShiftController::class, 'open']);
        Route::patch('/shifts/{shift}/close', [ShiftController::class, 'close']);
    });

    // Báo cáo ca (Admin xem mọi ca trong một ngày)
    Route::get('/shifts', [ShiftController::class, 'index'])->middleware('role:admin');

    // Tra cứu thành viên theo mã (thu ngân dùng khi quét QR)
    Route::get('/members/{code}', [MemberController::class, 'show'])->middleware('role:cashier,admin');

    // Báo cáo (admin)
    Route::get('/reports/overview', [ReportController::class, 'overview'])->middleware('role:admin');
    Route::get('/reports/revenue', [ReportController::class, 'revenue'])->middleware('role:admin');
    // Xuất Excel theo ngày / tháng / năm (cùng file với web /admin)
    Route::get('/reports/export-periods', [ReportExportController::class, 'periods'])->middleware('role:admin');
    Route::post('/reports/export-link', [ReportExportController::class, 'link'])->middleware('role:admin');

    // Món yêu thích & Thông báo (khách hàng)
    Route::middleware('role:customer')->group(function () {
        Route::get('/customers/me/favorites', [FavoriteController::class, 'index']);
        Route::post('/customers/me/favorites/{food}', [FavoriteController::class, 'toggle']);

        Route::get('/customers/me/notifications', [NotificationController::class, 'index']);
        Route::patch('/customers/me/notifications/{id}/read', [NotificationController::class, 'markRead']);
        Route::post('/customers/me/notifications/read-all', [NotificationController::class, 'markAllRead']);
    });

    // ── Thao tác bàn: Chuyển bàn / Gộp bàn (NV Order + Admin) ──────────────
    Route::middleware('role:order_staff,admin')->group(function () {
        Route::post('/tables/{table}/transfer', [TableOperationController::class, 'transfer']);
        Route::post('/tables/{table}/merge', [TableOperationController::class, 'merge']);
    });

    // ── Admin: CRUD tài khoản, thực đơn, bàn, khuyến mãi ───────────────────
    Route::middleware('role:admin')->prefix('admin')->group(function () {
        // Tài khoản
        Route::get('/users', [UserAdminController::class, 'index']);
        Route::post('/users', [UserAdminController::class, 'store']);
        Route::put('/users/{user}', [UserAdminController::class, 'update']);
        Route::patch('/users/{user}/toggle-status', [UserAdminController::class, 'toggleStatus']);
        Route::patch('/users/{user}/reset-password', [UserAdminController::class, 'resetPassword']);
        Route::delete('/users/{user}', [UserAdminController::class, 'destroy']);

        // Đơn đã hủy (lý do, người hủy) theo ngày
        Route::get('/cancelled-orders', [CancelOrderController::class, 'index']);

        // Danh mục
        Route::get('/categories', [CategoryAdminController::class, 'index']);
        Route::post('/categories', [CategoryAdminController::class, 'store']);
        Route::put('/categories/{category}', [CategoryAdminController::class, 'update']);
        Route::delete('/categories/{category}', [CategoryAdminController::class, 'destroy']);

        // Món ăn
        Route::get('/foods', [FoodAdminController::class, 'index']);
        Route::post('/foods', [FoodAdminController::class, 'store']);
        Route::put('/foods/{food}', [FoodAdminController::class, 'update']);
        Route::patch('/foods/{food}/toggle-available', [FoodAdminController::class, 'toggleAvailable']);
        Route::delete('/foods/{food}', [FoodAdminController::class, 'destroy']);

        // Bàn ăn
        Route::get('/tables', [TableAdminController::class, 'index']);
        Route::post('/tables', [TableAdminController::class, 'store']);
        Route::put('/tables/{table}', [TableAdminController::class, 'update']);
        Route::patch('/tables/{table}/toggle-locked', [TableAdminController::class, 'toggleLocked']);
        Route::patch('/tables/{table}/toggle-active', [TableAdminController::class, 'toggleActive']);

        // Khuyến mãi
        Route::get('/promotions', [PromotionAdminController::class, 'index']);
        Route::post('/promotions', [PromotionAdminController::class, 'store']);
        Route::put('/promotions/{promotion}', [PromotionAdminController::class, 'update']);
        Route::patch('/promotions/{promotion}/toggle-active', [PromotionAdminController::class, 'toggleActive']);
    });
});
