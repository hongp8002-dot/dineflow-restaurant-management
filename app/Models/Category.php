<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Category extends Model
{
    protected $fillable = ['name', 'icon', 'sort_order'];

    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
        ];
    }

    public function foods(): HasMany
    {
        return $this->hasMany(Food::class);
    }

    /**
     * Lý do không được xóa danh mục (null = xóa được). Còn món thì chặn, không xóa dây chuyền
     * để tránh mất món. Dùng chung cho API của app Admin và trang Danh mục trên web /admin.
     */
    public function deletionBlockedReason(): ?string
    {
        $foodCount = $this->foods()->count();

        return $foodCount > 0
            ? "Không thể xóa danh mục \"{$this->name}\" vì còn {$foodCount} món. Hãy chuyển hoặc ẩn các món trước."
            : null;
    }

    public function scopeOrdered(Builder $query): Builder
    {
        return $query->orderBy('sort_order')->orderBy('name');
    }
}
