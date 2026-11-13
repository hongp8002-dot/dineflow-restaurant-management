<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Models\PasswordResetOtp;
use App\Models\User;
use App\Notifications\PasswordResetOtpNotification;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Validation\ValidationException;
use RuntimeException;
use Throwable;

/**
 * Quên mật khẩu bằng mã OTP gửi qua email — chỉ dành cho tài khoản KHÁCH HÀNG (nhóm chốt 13/11).
 *
 * Quy tắc đã chốt:
 *  - Mã 6 chữ số, hiệu lực 10 phút.
 *  - Nhập sai tối đa 5 lần; sai lần thứ 5 thì mã bị hủy, phải xin mã mới.
 *  - Mỗi email chỉ xin mã được 1 lần / 60 giây.
 *
 * Luồng: send() gửi mã → verify() kiểm tra mã (bước 2 của app) → reset() kiểm tra lại mã,
 * đổi mật khẩu, xóa mã và đăng xuất mọi thiết bị đang đăng nhập tài khoản đó.
 */
class PasswordResetOtpService
{
    public const CODE_LENGTH = 6;

    public const EXPIRES_MINUTES = 10;

    public const MAX_ATTEMPTS = 5;

    public const RESEND_SECONDS = 60;

    /**
     * Gửi mã tới email. Email không thuộc tài khoản khách hàng đang hoạt động thì KHÔNG gửi
     * nhưng vẫn trả lời như thường, để người ngoài không dò được email nào có tài khoản.
     *
     * @throws ValidationException khi xin mã lại quá sớm
     * @throws RuntimeException khi máy chủ mail lỗi
     */
    public function send(string $email): void
    {
        $email = mb_strtolower(trim($email));
        $key = 'password-otp:'.$email;

        // Giới hạn theo email (kể cả email không tồn tại) nên không lộ thông tin tài khoản.
        if (RateLimiter::tooManyAttempts($key, 1)) {
            $seconds = RateLimiter::availableIn($key);
            throw ValidationException::withMessages([
                'email' => "Vui lòng đợi {$seconds} giây rồi gửi lại mã.",
                // Số giây còn phải chờ, để app chuyển sang bước nhập mã và đếm ngược
                'retry_after' => (string) $seconds,
            ]);
        }
        RateLimiter::hit($key, self::RESEND_SECONDS);

        $user = $this->findCustomer($email);
        if (! $user) {
            return;
        }

        $code = str_pad((string) random_int(0, 10 ** self::CODE_LENGTH - 1), self::CODE_LENGTH, '0', STR_PAD_LEFT);

        // Mỗi tài khoản 1 mã: xin mã mới thì mã cũ hết tác dụng, số lần sai đếm lại từ 0.
        $otp = PasswordResetOtp::updateOrCreate(
            ['user_id' => $user->id],
            [
                'code_hash' => Hash::make($code),
                'attempts' => 0,
                'expires_at' => now()->addMinutes(self::EXPIRES_MINUTES),
            ],
        );

        try {
            $user->notify(new PasswordResetOtpNotification($code, self::EXPIRES_MINUTES));
        } catch (Throwable $e) {
            report($e);
            $otp->delete();
            RateLimiter::clear($key); // gửi hỏng thì cho thử lại ngay
            throw new RuntimeException('Không gửi được email lúc này. Vui lòng thử lại sau.');
        }
    }

    /**
     * Kiểm tra mã (không dùng hết mã). Sai thì tăng số lần sai; sai đủ 5 lần thì hủy mã.
     *
     * @throws ValidationException
     */
    public function verify(string $email, string $code): PasswordResetOtp
    {
        $user = $this->findCustomer(mb_strtolower(trim($email)));
        $otp = $user ? PasswordResetOtp::where('user_id', $user->id)->first() : null;

        if (! $otp) {
            $this->failCode('Mã xác nhận không đúng hoặc đã hết hạn. Vui lòng lấy mã mới.');
        }

        if ($otp->isExpired()) {
            $otp->delete();
            $this->failCode('Mã xác nhận đã hết hạn. Vui lòng lấy mã mới.');
        }

        if (! Hash::check($code, $otp->code_hash)) {
            $otp->increment('attempts');

            if ($otp->attempts >= self::MAX_ATTEMPTS) {
                $otp->delete();
                $this->failCode('Bạn đã nhập sai '.self::MAX_ATTEMPTS.' lần. Mã đã bị hủy, vui lòng lấy mã mới.');
            }

            $left = self::MAX_ATTEMPTS - $otp->attempts;
            $this->failCode("Mã xác nhận không đúng. Bạn còn {$left} lần thử.");
        }

        return $otp;
    }

    /**
     * Đặt mật khẩu mới sau khi kiểm tra lại mã. Đổi xong: xóa mã, thu hồi mọi token
     * (các thiết bị đang đăng nhập tài khoản này phải đăng nhập lại).
     *
     * @throws ValidationException
     */
    public function reset(string $email, string $code, string $password): void
    {
        // Kiểm tra mã NGOÀI transaction để số lần nhập sai vẫn được lưu khi mã sai.
        $otp = $this->verify($email, $code);

        DB::transaction(function () use ($otp, $password) {
            $user = $otp->user;
            $user->update(['password' => $password]); // cast 'hashed' tự mã hóa
            $user->tokens()->delete();
            $otp->delete();
        });
    }

    private function findCustomer(string $email): ?User
    {
        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();

        return $user && $user->role === UserRole::Customer && $user->isActive() ? $user : null;
    }

    /** @throws ValidationException */
    private function failCode(string $message): never
    {
        throw ValidationException::withMessages(['code' => $message]);
    }
}
