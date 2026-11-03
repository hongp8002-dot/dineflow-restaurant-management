<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Tài khoản người dùng (dành riêng cho Admin quản lý — có email, phone, status).
 * Không trả password hay token.
 *
 * @mixin \App\Models\User
 */
class UserAdminResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'phone' => $this->phone ?? '',
            'role' => $this->role->value,
            'status' => $this->status->value,
            'avatar_url' => $this->avatar_url,
            'member_code' => $this->member_code,
            'points' => (int) $this->points,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
