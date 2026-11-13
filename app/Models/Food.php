<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class Food extends Model
{
    protected $table = 'foods';

    protected $fillable = [
        'category_id',
        'name',
        'price',
        'description',
        'image',
        'icon',
        'color',
        'rating',
        'is_best_seller',
        'is_available',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'rating' => 'float',
            'is_best_seller' => 'boolean',
            'is_available' => 'boolean',
        ];
    }

    /* ---------------- Relationships ---------------- */

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function options(): HasMany
    {
        return $this->hasMany(FoodOption::class);
    }

    public function orderItems(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    /**
     * Lý do không được xóa món, hoặc null nếu xóa được. Dùng chung cho app Admin (API) và web /admin.
     * - Món nằm trong món đặt trước của lượt đặt "Sắp tới": nhận bàn sẽ không chép được món vào đơn.
     * - Món nằm trong đơn chưa thanh toán: đơn đang phục vụ mất liên kết món.
     * Hóa đơn cũ đã thanh toán không chặn: dòng món giữ tên món (food_name) nên báo cáo không đổi.
     */
    public function deletionBlockedReason(): ?string
    {
        $inOpenOrder = $this->orderItems()
            ->whereHas('order', fn (Builder $q) => $q
                ->where('payment_status', '!=', \App\Enums\PaymentStatus::Paid)
                ->where('status', '!=', \App\Enums\OrderStatus::Cancelled))
            ->exists();

        if ($inOpenOrder) {
            return "Không thể xóa \"{$this->name}\" vì món đang có trong đơn chưa thanh toán. Hãy ẩn món (hết món) thay vì xóa.";
        }

        $inPreOrder = Reservation::where('status', \App\Enums\ReservationStatus::Upcoming)
            ->whereNotNull('pre_order_items')
            ->get(['id', 'pre_order_items'])
            ->contains(fn (Reservation $r) => collect($r->pre_order_items)->contains('food_id', $this->id));

        if ($inPreOrder) {
            return "Không thể xóa \"{$this->name}\" vì khách đã đặt trước món này cho lượt đặt bàn sắp tới. Hãy ẩn món (hết món) thay vì xóa.";
        }

        return null;
    }

    /* ---------------- Accessors ---------------- */

    /**
     * URL tuyệt đối của ảnh cho Flutter:
     * - Ảnh upload qua Filament (lưu path trong disk 'public') -> /storage/...
     * - Đã là URL http(s) -> giữ nguyên.
     */
    protected function imageUrl(): Attribute
    {
        return Attribute::get(function (): ?string {
            if (blank($this->image)) {
                return null;
            }

            return Str::startsWith($this->image, ['http://', 'https://'])
                ? $this->image
                : Storage::disk('public')->url($this->image);
        });
    }

    /* ---------------- Scopes ---------------- */

    public function scopeAvailable(Builder $query): Builder
    {
        return $query->where('is_available', true);
    }

    public function scopeSearch(Builder $query, ?string $keyword): Builder
    {
        return $query->when(filled($keyword), fn (Builder $q) => $q->where(function (Builder $q) use ($keyword) {
            $q->where('name', 'like', "%{$keyword}%")
                ->orWhere('description', 'like', "%{$keyword}%");
        }));
    }
}
