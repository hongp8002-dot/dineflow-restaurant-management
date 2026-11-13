<?php

namespace App\Http\Controllers\Api;

use App\Services\PasswordResetOtpService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

/**
 * Quên mật khẩu bằng OTP email (công khai, chỉ tài khoản khách hàng).
 * Quy tắc và logic: App\Services\PasswordResetOtpService.
 *
 *   POST /api/password/forgot  { email }                                  → gửi mã
 *   POST /api/password/verify  { email, code }                            → kiểm tra mã
 *   POST /api/password/reset   { email, code, password, password_confirmation } → đổi mật khẩu
 */
class PasswordResetController extends ApiController
{
    public function __construct(private readonly PasswordResetOtpService $otp) {}

    public function forgot(Request $request): JsonResponse
    {
        $data = $request->validate(
            ['email' => ['required', 'email', 'max:255']],
            ['email.required' => 'Vui lòng nhập email.', 'email.email' => 'Email không đúng định dạng.'],
        );

        try {
            $this->otp->send($data['email']);
        } catch (RuntimeException $e) {
            return $this->fail($e->getMessage(), 503);
        }

        return $this->ok([
            'expires_in' => PasswordResetOtpService::EXPIRES_MINUTES * 60,
            'resend_in' => PasswordResetOtpService::RESEND_SECONDS,
        ], 'Nếu email thuộc một tài khoản khách hàng, mã xác nhận đã được gửi. Vui lòng kiểm tra hộp thư (cả mục Spam).');
    }

    public function verify(Request $request): JsonResponse
    {
        $data = $request->validate($this->codeRules(), $this->messages());

        $this->otp->verify($data['email'], $data['code']);

        return $this->ok(null, 'Mã xác nhận đúng. Vui lòng đặt mật khẩu mới.');
    }

    public function reset(Request $request): JsonResponse
    {
        $data = $request->validate([
            ...$this->codeRules(),
            // Cùng quy tắc với đổi mật khẩu (PATCH /me/password)
            'password' => ['required', 'string', 'min:6', 'max:100', 'confirmed'],
        ], $this->messages());

        $this->otp->reset($data['email'], $data['code'], $data['password']);

        return $this->ok(null, 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới.');
    }

    private function codeRules(): array
    {
        return [
            'email' => ['required', 'email', 'max:255'],
            'code' => ['required', 'digits:'.PasswordResetOtpService::CODE_LENGTH],
        ];
    }

    private function messages(): array
    {
        return [
            'email.required' => 'Vui lòng nhập email.',
            'email.email' => 'Email không đúng định dạng.',
            'code.required' => 'Vui lòng nhập mã xác nhận.',
            'code.digits' => 'Mã xác nhận gồm '.PasswordResetOtpService::CODE_LENGTH.' chữ số.',
            'password.required' => 'Vui lòng nhập mật khẩu mới.',
            'password.min' => 'Mật khẩu mới phải có ít nhất 6 ký tự.',
            'password.confirmed' => 'Mật khẩu xác nhận không khớp.',
        ];
    }
}
