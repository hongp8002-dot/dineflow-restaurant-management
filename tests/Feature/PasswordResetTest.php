<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Enums\UserStatus;
use App\Models\PasswordResetOtp;
use App\Models\User;
use App\Notifications\PasswordResetOtpNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

/**
 * Quên mật khẩu bằng OTP email (quy tắc nhóm chốt 13/11):
 * chỉ khách hàng; mã 6 số, 10 phút; sai tối đa 5 lần; gửi lại sau 60 giây.
 */
class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    private function customer(array $attributes = []): User
    {
        return User::create([
            'name' => 'Khách Test',
            'email' => 'khach@test.com',
            'phone' => '0911111111',
            'password' => 'matkhaucu',
            'role' => UserRole::Customer,
            'status' => UserStatus::Active,
            ...$attributes,
        ]);
    }

    /** Gửi mã và lấy mã gốc từ email đã "gửi" (Notification::fake). */
    private function requestCode(string $email = 'khach@test.com'): ?string
    {
        $code = null;
        $this->postJson('/api/password/forgot', ['email' => $email])->assertOk();

        $user = User::where('email', $email)->first();
        if ($user) {
            Notification::assertSentTo($user, PasswordResetOtpNotification::class, function ($n) use (&$code, $user) {
                preg_match('/\d{6}/', $n->toMail($user)->subject, $m);
                $code = $m[0] ?? null;

                return true;
            });
        }

        return $code;
    }

    public function test_customer_resets_password_with_emailed_code(): void
    {
        Notification::fake();
        $user = $this->customer();
        $user->createToken('dien-thoai-cu');

        $code = $this->requestCode();
        $this->assertMatchesRegularExpression('/^\d{6}$/', $code);
        $this->assertNotSame($code, PasswordResetOtp::first()->code_hash, 'Chỉ lưu bản băm của mã');

        $this->postJson('/api/password/verify', ['email' => 'khach@test.com', 'code' => $code])->assertOk();

        $this->postJson('/api/password/reset', [
            'email' => 'khach@test.com',
            'code' => $code,
            'password' => 'matkhaumoi',
            'password_confirmation' => 'matkhaumoi',
        ])->assertOk();

        $user->refresh();
        $this->assertTrue(Hash::check('matkhaumoi', $user->password));
        $this->assertSame(0, $user->tokens()->count(), 'Đổi mật khẩu xong phải đăng xuất mọi thiết bị');
        $this->assertSame(0, PasswordResetOtp::count(), 'Mã dùng xong phải bị xóa');

        $this->postJson('/api/login', ['login' => 'khach@test.com', 'password' => 'matkhaumoi'])->assertOk();
        // Mã đã dùng thì không dùng lại được
        $this->postJson('/api/password/verify', ['email' => 'khach@test.com', 'code' => $code])->assertStatus(422);
    }

    public function test_unknown_email_and_staff_get_same_answer_but_no_email(): void
    {
        Notification::fake();
        $staff = $this->customer(['email' => 'nv@test.com', 'phone' => '0922222222', 'role' => UserRole::Cashier]);

        $unknown = $this->postJson('/api/password/forgot', ['email' => 'khongco@test.com'])->assertOk()->json('message');
        $forStaff = $this->postJson('/api/password/forgot', ['email' => 'nv@test.com'])->assertOk()->json('message');

        $this->assertSame($unknown, $forStaff, 'Không được để lộ email nào có tài khoản');
        Notification::assertNothingSent();
        $this->assertSame(0, PasswordResetOtp::count());
    }

    public function test_locked_customer_gets_no_code(): void
    {
        Notification::fake();
        $this->customer(['status' => UserStatus::Locked]);

        $this->postJson('/api/password/forgot', ['email' => 'khach@test.com'])->assertOk();

        Notification::assertNothingSent();
    }

    public function test_resend_is_blocked_for_60_seconds(): void
    {
        Notification::fake();
        $this->customer();

        $this->postJson('/api/password/forgot', ['email' => 'khach@test.com'])->assertOk();
        $this->postJson('/api/password/forgot', ['email' => 'khach@test.com'])
            ->assertStatus(422)
            ->assertJsonPath('status', 'error');

        $this->travel(61)->seconds();
        $this->postJson('/api/password/forgot', ['email' => 'khach@test.com'])->assertOk();
        Notification::assertSentTimes(PasswordResetOtpNotification::class, 2);
    }

    public function test_code_is_cancelled_after_five_wrong_attempts(): void
    {
        Notification::fake();
        $this->customer();
        $code = $this->requestCode();
        $wrong = $code === '000000' ? '111111' : '000000';

        for ($i = 1; $i <= 4; $i++) {
            $this->postJson('/api/password/verify', ['email' => 'khach@test.com', 'code' => $wrong])
                ->assertStatus(422)
                ->assertJsonPath('message', 'Mã xác nhận không đúng. Bạn còn '.(5 - $i).' lần thử.');
        }

        $this->postJson('/api/password/verify', ['email' => 'khach@test.com', 'code' => $wrong])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Bạn đã nhập sai 5 lần. Mã đã bị hủy, vui lòng lấy mã mới.');

        // Mã đúng cũng không dùng được nữa
        $this->postJson('/api/password/verify', ['email' => 'khach@test.com', 'code' => $code])->assertStatus(422);
        $this->assertSame(0, PasswordResetOtp::count());
    }

    public function test_wrong_code_on_reset_step_is_counted_too(): void
    {
        Notification::fake();
        $this->customer();
        $code = $this->requestCode();
        $wrong = $code === '000000' ? '111111' : '000000';

        $this->postJson('/api/password/reset', [
            'email' => 'khach@test.com', 'code' => $wrong,
            'password' => 'matkhaumoi', 'password_confirmation' => 'matkhaumoi',
        ])->assertStatus(422);

        $this->assertSame(1, PasswordResetOtp::first()->attempts);
        $this->assertTrue(Hash::check('matkhaucu', User::first()->password), 'Mã sai thì không đổi mật khẩu');
    }

    public function test_code_expires_after_10_minutes(): void
    {
        Notification::fake();
        $this->customer();
        $code = $this->requestCode();

        $this->travel(11)->minutes();

        $this->postJson('/api/password/verify', ['email' => 'khach@test.com', 'code' => $code])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Mã xác nhận đã hết hạn. Vui lòng lấy mã mới.');
    }

    public function test_new_code_replaces_old_one(): void
    {
        Notification::fake();
        $this->customer();
        $old = $this->requestCode();

        RateLimiter::clear('password-otp:khach@test.com');
        $this->postJson('/api/password/forgot', ['email' => 'khach@test.com'])->assertOk();

        $this->assertSame(1, PasswordResetOtp::count(), 'Mỗi tài khoản chỉ một mã');
        // Xác suất mã mới trùng mã cũ là 1/1.000.000 — bỏ qua trường hợp đó
        if (Hash::check($old, PasswordResetOtp::first()->code_hash)) {
            $this->markTestSkipped('Mã mới trùng mã cũ (rất hiếm).');
        }
        $this->postJson('/api/password/verify', ['email' => 'khach@test.com', 'code' => $old])->assertStatus(422);
    }
}
