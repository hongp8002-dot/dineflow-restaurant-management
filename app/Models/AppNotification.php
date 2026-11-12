<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Thông báo in-app cho khách hàng.
 *
 * @property int         $id
 * @property int         $customer_id
 * @property string      $type          reservation_confirmed | reservation_cancelled
 * @property string      $title
 * @property string      $body
 * @property array|null  $data
 * @property \Illuminate\Support\Carbon|null $read_at
 * @property \Illuminate\Support\Carbon      $created_at
 * @property \Illuminate\Support\Carbon      $updated_at
 */
class AppNotification extends Model
{
    protected $table = 'notifications';

    protected $fillable = [
        'customer_id',
        'type',
        'title',
        'body',
        'data',
        'read_at',
    ];

    protected $casts = [
        'data'    => 'array',
        'read_at' => 'datetime',
    ];

    // -------------------------------------------------------------------------
    // Quan hệ
    // -------------------------------------------------------------------------

    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    // -------------------------------------------------------------------------
    // Helpers tạo nhanh
    // -------------------------------------------------------------------------

    /**
     * Tạo thông báo "Đặt bàn thành công" cho khách.
     */
    public static function reservationConfirmed(int $customerId, int $reservationId, string $dateTime): self
    {
        return self::create([
            'customer_id' => $customerId,
            'type'        => 'reservation_confirmed',
            'title'       => 'Đặt bàn thành công',
            'body'        => "Lượt đặt bàn của bạn vào {$dateTime} đã được xác nhận.",
            'data'        => ['reservation_id' => $reservationId],
        ]);
    }

    /**
     * Tạo thông báo "Đặt bàn đã hủy" cho khách.
     */
    public static function reservationCancelled(int $customerId, int $reservationId, string $dateTime): self
    {
        return self::create([
            'customer_id' => $customerId,
            'type'        => 'reservation_cancelled',
            'title'       => 'Đặt bàn đã bị hủy',
            'body'        => "Lượt đặt bàn của bạn vào {$dateTime} đã bị hủy.",
            'data'        => ['reservation_id' => $reservationId],
        ]);
    }
}
