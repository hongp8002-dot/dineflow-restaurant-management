<?php

namespace App\Models;

use App\Enums\TableStatus;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Bàn ăn (bảng `tables`).
 * Đặt tên DiningTable để không đụng với Filament\Tables\Table trong các Resource.
 */
class DiningTable extends Model
{
    protected $table = 'tables';

    protected $fillable = [
        'number',
        'area',
        'capacity',
        'status',
        'serving_since',
        'current_order_id',
        'is_locked',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'capacity' => 'integer',
            'status' => TableStatus::class,
            'serving_since' => 'datetime',
            'is_locked' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    /* ---------------- Relationships ---------------- */

    public function currentOrder(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'current_order_id');
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'table_id');
    }

    /* ---------------- Business helpers ---------------- */

    public function isEmpty(): bool
    {
        return $this->status === TableStatus::Empty;
    }

    /** Bàn có thể được mở không (không bị khóa, không bị vô hiệu hóa, đang trống). */
    public function canBeOpened(): bool
    {
        return $this->is_active && !$this->is_locked && $this->isEmpty();
    }

    /** Gắn đơn hàng đang phục vụ vào bàn. */
    public function occupy(Order $order): void
    {
        $this->update([
            'status' => TableStatus::Serving,
            'serving_since' => $this->serving_since ?? now(),
            'current_order_id' => $order->id,
        ]);
    }

    /** Giải phóng bàn về trạng thái trống (sau khi thanh toán / hủy đơn). */
    public function release(): void
    {
        $this->update([
            'status' => TableStatus::Empty,
            'serving_since' => null,
            'current_order_id' => null,
        ]);
    }

    /* ---------------- Scopes ---------------- */

    public function scopeStatus(Builder $query, TableStatus $status): Builder
    {
        return $query->where('status', $status);
    }

    public function scopeInArea(Builder $query, ?string $area): Builder
    {
        return $query->when(filled($area), fn (Builder $q) => $q->where('area', $area));
    }

    /** Chỉ lấy bàn đang hoạt động (app hiển thị). Admin xem tất cả không cần scope này. */
    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }
}
