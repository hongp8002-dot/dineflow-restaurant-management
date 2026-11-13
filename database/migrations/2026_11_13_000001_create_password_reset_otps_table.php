<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Mã OTP quên mật khẩu (chỉ tài khoản khách hàng).
 * Quan hệ: users 1 – 0..1 password_reset_otps. Mỗi tài khoản chỉ có tối đa MỘT mã còn hiệu lực:
 * xin mã mới thì ghi đè mã cũ. Xóa tài khoản thì xóa luôn mã.
 * Chỉ lưu bản băm của mã (code_hash), không lưu mã gốc.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('password_reset_otps', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('code_hash');
            $table->unsignedTinyInteger('attempts')->default(0); // số lần nhập sai
            $table->timestamp('expires_at');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('password_reset_otps');
    }
};
