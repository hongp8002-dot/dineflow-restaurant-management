<?php

namespace App\Http\Controllers\Api\Admin;

use App\Enums\UserRole;
use App\Enums\UserStatus;
use App\Http\Controllers\Api\ApiController;
use App\Http\Resources\UserAdminResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

/**
 * CRUD tài khoản nhân viên & khách hàng (chỉ Admin).
 *
 * Chính sách xóa: KHÔNG hard delete. Tài khoản đã có lịch sử đơn hàng chỉ bị
 * khóa (status = locked). Không bao giờ xóa vật lý để giữ toàn vẹn báo cáo.
 *
 * Mật khẩu mặc định khi tạo tài khoản nhân viên: 123456
 */
class UserAdminController extends ApiController
{
    /**
     * GET /api/admin/users?role=&status=&search=
     *
     * Admin xem tất cả tài khoản: nhân viên, thu ngân, khách hàng.
     * Hỗ trợ lọc theo vai trò, trạng thái, tìm theo tên/email.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'role' => ['nullable', Rule::enum(UserRole::class)],
            'status' => ['nullable', Rule::enum(UserStatus::class)],
            'search' => ['nullable', 'string', 'max:100'],
        ]);

        $users = User::query()
            ->when($request->filled('role'), fn ($q) => $q->where('role', $request->input('role')))
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->input('status')))
            ->when($request->filled('search'), function ($q) use ($request) {
                $s = '%' . $request->input('search') . '%';
                $q->where(fn ($q2) => $q2->where('name', 'like', $s)->orWhere('email', 'like', $s));
            })
            ->orderBy('role')
            ->orderBy('name')
            ->get();

        return $this->ok($this->items($users, UserAdminResource::class));
    }

    /**
     * POST /api/admin/users
     *
     * Tạo tài khoản nhân viên (order_staff hoặc cashier).
     * Mật khẩu mặc định: 123456 — nhân viên tự đổi sau khi đăng nhập lần đầu.
     * Admin không tạo tài khoản admin khác (role admin được tạo trực tiếp trong DB).
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:150', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:20'],
            'role' => ['required', Rule::in([UserRole::OrderStaff->value, UserRole::Cashier->value])],
        ]);

        $user = User::create([
            ...$data,
            'password' => Hash::make('123456'),
            'status' => UserStatus::Active,
        ]);

        return $this->ok(UserAdminResource::make($user)->resolve(request()), 'Tạo tài khoản thành công', 201);
    }

    /**
     * PUT /api/admin/users/{user}
     *
     * Cập nhật thông tin (không cho đổi mật khẩu qua đây — dùng /me/password).
     */
    public function update(Request $request, User $user): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'email' => ['sometimes', 'required', 'email', 'max:150', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => ['nullable', 'string', 'max:20'],
            'role' => ['sometimes', Rule::in([UserRole::OrderStaff->value, UserRole::Cashier->value])],
        ]);

        $user->update($data);

        return $this->ok(UserAdminResource::make($user->fresh())->resolve(request()), 'Cập nhật thành công');
    }

    /**
     * PATCH /api/admin/users/{user}/reset-password
     *
     * Đặt lại mật khẩu nhân viên về 123456 và đăng xuất mọi thiết bị (User::resetToDefaultPassword).
     */
    public function resetPassword(User $user): JsonResponse
    {
        $user->resetToDefaultPassword();

        return $this->ok(null, "Đã đặt lại mật khẩu của {$user->name} về ".User::DEFAULT_PASSWORD.'. Nhân viên đăng nhập lại và tự đổi mật khẩu.');
    }

    /**
     * PATCH /api/admin/users/{user}/toggle-status
     *
     * Khóa / Kích hoạt tài khoản. Không xóa — giữ lịch sử đơn hàng.
     * Admin không thể tự khóa mình.
     */
    public function toggleStatus(Request $request, User $user): JsonResponse
    {
        if ($user->id === $request->user()->id) {
            return $this->fail('Không thể khóa tài khoản của chính mình', 422);
        }

        $newStatus = $user->status === UserStatus::Active ? UserStatus::Locked : UserStatus::Active;
        $user->update(['status' => $newStatus]);

        $message = $newStatus === UserStatus::Locked
            ? "Đã khóa tài khoản {$user->name}"
            : "Đã kích hoạt tài khoản {$user->name}";

        return $this->ok(UserAdminResource::make($user->fresh())->resolve(request()), $message);
    }

    /**
     * DELETE /api/admin/users/{user}
     *
     * Vì không hard delete, endpoint này thực ra chỉ KHÓA tài khoản (giống toggleStatus).
     * Giữ endpoint DELETE để UI trực quan; server trả về trạng thái mới.
     */
    public function destroy(Request $request, User $user): JsonResponse
    {
        if ($user->id === $request->user()->id) {
            return $this->fail('Không thể xóa tài khoản của chính mình', 422);
        }

        $user->update(['status' => UserStatus::Locked]);

        return $this->ok(null, "Đã khóa tài khoản {$user->name}");
    }
}
