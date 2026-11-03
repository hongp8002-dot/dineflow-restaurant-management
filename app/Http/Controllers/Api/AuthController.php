<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Enums\UserStatus;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends ApiController
{
    public function login(Request $request): JsonResponse
    {
        // Đăng nhập bằng email hoặc số điện thoại: gửi vào `login` (hoặc `email` cho tương thích cũ)
        $data = $request->validate([
            'login' => ['required_without:email', 'nullable', 'string', 'max:255'],
            'email' => ['required_without:login', 'nullable', 'string', 'max:255'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ]);

        $user = $this->findByIdentifier(trim($data['login'] ?? $data['email']));

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            return $this->fail('Email hoặc mật khẩu không đúng.', 401);
        }

        if (! $user->isActive()) {
            return $this->fail('Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản lý.', 403);
        }

        return $this->ok($this->tokenPayload($user, $data['device_name'] ?? 'mobile'), 'Đăng nhập thành công.');
    }

    /** Đăng ký tài khoản khách hàng. */
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:20', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:6', 'max:100'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'] ?? null,
            'password' => $data['password'], // cast 'hashed' tự mã hóa
            'role' => UserRole::Customer,    // đăng ký công khai luôn là khách hàng
            'status' => UserStatus::Active,
        ]);
        $user->update(['member_code' => sprintf('DF-MB%04d', $user->id)]);

        return $this->ok($this->tokenPayload($user, $data['device_name'] ?? 'mobile'), 'Đăng ký thành công.', 201);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return $this->ok(null, 'Đã đăng xuất.');
    }

    public function me(Request $request): JsonResponse
    {
        return $this->ok(UserResource::make($request->user()));
    }

    /**
     * Người dùng tự đổi mật khẩu (mọi vai trò).
     * Phải nhập đúng mật khẩu hiện tại. Đổi xong thì thu hồi mọi token khác
     * (các máy khác phải đăng nhập lại), giữ token của máy đang dùng.
     */
    public function changePassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'min:6', 'max:100', 'confirmed', 'different:current_password'],
        ], [
            'current_password.required' => 'Vui lòng nhập mật khẩu hiện tại.',
            'password.required' => 'Vui lòng nhập mật khẩu mới.',
            'password.min' => 'Mật khẩu mới phải có ít nhất 6 ký tự.',
            'password.confirmed' => 'Mật khẩu xác nhận không khớp.',
            'password.different' => 'Mật khẩu mới phải khác mật khẩu hiện tại.',
        ]);

        $user = $request->user();

        if (! Hash::check($data['current_password'], $user->password)) {
            $message = 'Mật khẩu hiện tại không đúng.';

            return $this->fail($message, 422, ['current_password' => [$message]]);
        }

        $user->update(['password' => $data['password']]); // cast 'hashed' tự mã hóa

        $current = $user->currentAccessToken();
        $user->tokens()->when($current?->id, fn ($q, $id) => $q->where('id', '!=', $id))->delete();

        return $this->ok(null, 'Đổi mật khẩu thành công.');
    }

    /** Có dấu @ thì tìm theo email, ngược lại tìm theo số điện thoại (bỏ khoảng trắng, dấu chấm, gạch). */
    private function findByIdentifier(string $identifier): ?User
    {
        if (str_contains($identifier, '@')) {
            return User::where('email', $identifier)->first();
        }

        $phone = preg_replace('/\D+/', '', $identifier);

        return $phone === '' ? null : User::where('phone', $phone)->first();
    }

    private function tokenPayload(User $user, string $device): array
    {
        return [
            'token' => $user->createToken($device)->plainTextToken,
            'token_type' => 'Bearer',
            'user' => UserResource::make($user)->resolve(),
        ];
    }
}
