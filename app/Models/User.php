<?php

namespace App\Models;

use App\Enums\UserRole;
use App\Enums\UserStatus;
use Filament\Models\Contracts\FilamentUser;
use Filament\Models\Contracts\HasAvatar;
use Filament\Panel;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable implements FilamentUser, HasAvatar
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'phone',
        'password',
        'role',
        'status',
        'avatar_url',
        'member_code',
        'points',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'role' => UserRole::class,
            'status' => UserStatus::class,
            'points' => 'integer',
        ];
    }

    /* ---------------- Filament ---------------- */

    /** Chỉ Admin đang hoạt động mới vào được /admin. */
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->role === UserRole::Admin && $this->isActive();
    }

    public function getFilamentAvatarUrl(): ?string
    {
        return $this->avatar_url;
    }

    /* ---------------- Relationships ---------------- */

    /** Đơn hàng mà user là khách. */
    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'customer_id');
    }

    /** Đơn hàng do nhân viên này tạo. */
    public function createdOrders(): HasMany
    {
        return $this->hasMany(Order::class, 'staff_id');
    }

    public function reservations(): HasMany
    {
        return $this->hasMany(Reservation::class, 'customer_id');
    }

    /** Hóa đơn do thu ngân này thu. */
    public function collectedInvoices(): HasMany
    {
        return $this->hasMany(Invoice::class, 'cashier_id');
    }

    /* ---------------- Helpers & scopes ---------------- */

    /** Mật khẩu mặc định khi Admin tạo / đặt lại tài khoản nhân viên. */
    public const DEFAULT_PASSWORD = '123456';

    /**
     * Admin đặt lại mật khẩu NHÂN VIÊN (NV Order / Thu ngân) về mặc định và đăng xuất mọi thiết bị.
     * Dùng chung cho API (app Admin) và nút trên web /admin. Khách hàng tự đặt lại bằng
     * "Quên mật khẩu" (OTP email); Admin không đặt lại mật khẩu Admin khác ở đây.
     * Mật khẩu lưu dạng băm (bcrypt) nên không ai xem được mật khẩu cũ — chỉ đặt lại.
     *
     * @throws \Illuminate\Validation\ValidationException
     */
    public function resetToDefaultPassword(): void
    {
        if (! in_array($this->role, [UserRole::OrderStaff, UserRole::Cashier], true)) {
            throw \Illuminate\Validation\ValidationException::withMessages([
                'user' => $this->role === UserRole::Customer
                    ? 'Khách hàng tự đặt lại mật khẩu bằng chức năng "Quên mật khẩu" trên app.'
                    : 'Chỉ đặt lại được mật khẩu của NV Order và Thu ngân.',
            ]);
        }

        $this->update(['password' => self::DEFAULT_PASSWORD]); // cast 'hashed' tự mã hóa
        $this->tokens()->delete();
    }

    public function isActive(): bool
    {
        return $this->status === UserStatus::Active;
    }

    public function hasRole(UserRole ...$roles): bool
    {
        return in_array($this->role, $roles, true);
    }

    public function scopeRole(Builder $query, UserRole $role): Builder
    {
        return $query->where('role', $role);
    }

    public function scopeStaff(Builder $query): Builder
    {
        return $query->where('role', '!=', UserRole::Customer);
    }
}
