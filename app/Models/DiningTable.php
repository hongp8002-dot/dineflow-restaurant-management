<?php

namespace App\Models;

use App\Enums\TableStatus;
use Illuminate\Database\Eloquent\Builder;
use Carbon\CarbonInterface;
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

    /**
     * Bàn có nhận khách đặt trước vào thời điểm $at không (chưa xét trùng lượt đặt khác).
     *
     * - Bàn bị vô hiệu hóa hoặc đang khóa: không nhận.
     * - Bàn đang có khách ngồi: chỉ chặn khi giờ đặt nằm trong WINDOW_MINUTES phút tới,
     *   vì khách hiện tại chưa chắc đã ăn xong. Đặt cho giờ xa hơn thì vẫn nhận; khách ăn xong
     *   sớm thì thu ngân thanh toán → bàn tự trống lại và đặt được ngay.
     * - Trùng giờ với lượt đặt khác do nơi gọi kiểm tra riêng (dựa trên bảng reservations).
     */
    public function isBookableAt(CarbonInterface $at): bool
    {
        if (! $this->is_active || $this->is_locked) {
            return false;
        }

        $servingNow = $this->status === TableStatus::Serving;

        return ! ($servingNow && $at->lt(now()->addMinutes(Reservation::WINDOW_MINUTES)));
    }

    /** Lý do bàn không nhận đặt (dùng cho thông báo lỗi); null nếu đặt được. */
    public function unbookableReason(CarbonInterface $at): ?string
    {
        if (! $this->is_active) {
            return "{$this->number} đã ngừng phục vụ.";
        }
        if ($this->is_locked) {
            return "{$this->number} đang tạm khóa.";
        }
        if (! $this->isBookableAt($at)) {
            return "{$this->number} đang có khách, chỉ nhận đặt từ ".now()->addMinutes(Reservation::WINDOW_MINUTES)->format('H:i').' trở đi.';
        }

        return null;
    }

    /**
     * Lượt đặt sớm nhất đang "giữ" bàn này cho khách đặt trước: còn hiệu lực và có giờ hẹn trong
     * khoảng [bây giờ − GRACE_MINUTES, bây giờ + WINDOW_MINUTES]. Nghĩa là khách sắp tới trong
     * 90 phút, hoặc đã tới giờ và vẫn đang trong 15 phút chờ. Null nếu không có.
     */
    public function heldReservation(): ?Reservation
    {
        return Reservation::blocking()
            ->whereJsonContains('table_ids', $this->id)
            ->whereBetween('date_time', [
                now()->subMinutes(Reservation::GRACE_MINUTES),
                now()->addMinutes(Reservation::WINDOW_MINUTES),
            ])
            ->orderBy('date_time')
            ->first();
    }

    /**
     * Lý do không mở bàn này cho khách vãng lai (null nếu mở được). Gọi Reservation::expireStale()
     * trước để lượt đã quá 15 phút không còn chặn bàn.
     */
    public function walkInBlockReason(): ?string
    {
        $reservation = $this->heldReservation();

        return $reservation
            ? "{$this->number} có khách đặt lúc {$reservation->date_time->format('H:i')} (mã {$reservation->code}). "
                .'Hãy chọn bàn khác, hoặc vào Lịch đặt bàn để nhận bàn cho khách đặt.'
            : null;
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
