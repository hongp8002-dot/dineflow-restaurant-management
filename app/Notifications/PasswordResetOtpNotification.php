<?php

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Email chứa mã OTP đặt lại mật khẩu. Gửi ngay (không qua hàng đợi) để khách nhận mã liền.
 * Cấu hình máy chủ gửi mail (Gmail SMTP) nằm trong file .env: MAIL_MAILER, MAIL_HOST, ...
 * Khi MAIL_MAILER=log, email được ghi vào storage/logs/laravel.log (dùng khi chưa cấu hình Gmail).
 */
class PasswordResetOtpNotification extends Notification
{
    public function __construct(
        private readonly string $code,
        private readonly int $expiresInMinutes,
    ) {}

    /** @return array<int, string> */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Mã đặt lại mật khẩu DineFlow: '.$this->code)
            ->greeting('Xin chào '.$notifiable->name.',')
            ->line('Bạn vừa yêu cầu đặt lại mật khẩu tài khoản DineFlow. Mã xác nhận của bạn là:')
            ->line('**'.$this->code.'**')
            ->line("Mã có hiệu lực trong {$this->expiresInMinutes} phút. Không chia sẻ mã này cho bất kỳ ai, kể cả nhân viên nhà hàng.")
            ->line('Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này — mật khẩu của bạn vẫn giữ nguyên.')
            ->salutation('DineFlow Restaurant');
    }
}
