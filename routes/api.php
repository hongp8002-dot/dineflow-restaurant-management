<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CancelOrderController;
use App\Http\Controllers\Api\CheckoutController;
use App\Http\Controllers\Api\InvoiceController;
use App\Http\Controllers\Api\MemberController;
use App\Http\Controllers\Api\MenuController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ReservationController;
use App\Http\Controllers\Api\ShiftController;
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
});

// Cần đăng nhập và tài khoản không bị khóa
Route::middleware(['auth:sanctum', 'active'])->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::patch('/me/password', [AuthController::class, 'changePassword']);

    // Thực đơn, bàn, khuyến mãi: mọi vai trò đều xem được
    Route::get('/categories', [MenuController::class, 'categories']);
    Route::get('/foods', [MenuController::class, 'foods']);
    Route::get('/promotions', [MenuController::class, 'promotions']);
    Route::get('/tables', [TableController::class, 'index']);

    // Đặt bàn (khách hàng)
    Route::get('/reservations/my', [ReservationController::class, 'my']);
    Route::post('/reservations', [ReservationController::class, 'store'])->middleware('role:customer');
    Route::post('/reservations/{reservation}/confirm', [ReservationController::class, 'confirm'])->middleware('role:customer');
    Route::patch('/reservations/{reservation}/cancel', [ReservationController::class, 'cancel']);

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

    // Tra cứu thành viên theo mã (thu ngân dùng khi quét QR)
    Route::get('/members/{code}', [MemberController::class, 'show'])->middleware('role:cashier,admin');

    // Báo cáo (admin)
    Route::get('/reports/overview', [ReportController::class, 'overview'])->middleware('role:admin');
    Route::get('/reports/revenue', [ReportController::class, 'revenue'])->middleware('role:admin');

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
        Route::delete('/users/{user}', [UserAdminController::class, 'destroy']);

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
