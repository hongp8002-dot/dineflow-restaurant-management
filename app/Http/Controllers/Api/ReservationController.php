<?php

namespace App\Http\Controllers\Api;

use App\Enums\PaymentMethod;
use App\Enums\ReservationStatus;
use App\Enums\UserRole;
use App\Http\Resources\OrderResource;
use App\Http\Resources\ReservationResource;
use App\Models\AppNotification;
use App\Models\DiningTable;
use App\Models\Reservation;
use App\Services\LineItemBuilder;
use App\Services\ReservationCheckIn;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class ReservationController extends ApiController
{
    /** Thời gian giữ bàn chờ khách xác nhận (đặt bàn qua app gồm 3 bước). */
    public const HOLD_MINUTES = 10;

    public function __construct(private LineItemBuilder $builder) {}

    /**
     * POST /api/reservations  (khách hàng)
     *
     * Mặc định đặt xong là xác nhận luôn. Gửi `hold=true` để chỉ GIỮ BÀN {HOLD_MINUTES} phút:
     * khách hoàn tất các bước còn lại (đặt món trước, thanh toán) rồi gọi `POST /reservations/{id}/confirm`;
     * quá hạn mà không xác nhận thì lượt đặt tự hủy và bàn được nhả (kể cả khi app bị tắt giữa chừng).
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'table_ids' => ['required', 'array', 'min:1', 'max:10'],
            'table_ids.*' => ['integer', 'distinct', 'exists:tables,id'],
            'date_time' => ['required', 'date', 'after:now'],
            'guest_count' => ['required', 'integer', 'min:1', 'max:100'],
            'note' => ['nullable', 'string', 'max:500'],
            'hold' => ['nullable', 'boolean'],
            'pre_order_payment' => ['required_with:pre_order_items', 'nullable', Rule::enum(PaymentMethod::class)],
            ...LineItemBuilder::rules('pre_order_items', required: false),
        ]);

        // Client có thể gửi giờ UTC ("...Z") hoặc kèm múi giờ khác: luôn đổi về múi giờ của quán trước khi lưu.
        $dateTime = Carbon::parse($data['date_time'])->setTimezone(config('app.timezone'));
        $tableIds = array_map('intval', $data['table_ids']);
        $lines = ! empty($data['pre_order_items']) ? $this->builder->build($data['pre_order_items'], 'pre_order_items') : [];

        // Dọn lượt giữ bàn quá hạn / khách trễ quá 15 phút trước khi kiểm tra trùng lịch.
        // Đặt ngoài transaction để việc dọn không bị rollback khi bên dưới báo lỗi.
        Reservation::expireStale();

        $reservation = DB::transaction(function () use ($request, $data, $dateTime, $tableIds, $lines) {
            $tables = DiningTable::whereIn('id', $tableIds)->lockForUpdate()->get();

            if ($tables->pluck('area')->unique()->count() > 1) {
                throw ValidationException::withMessages(['table_ids' => 'Các bàn ghép phải nằm trong cùng một khu vực.']);
            }

            // Cùng quy tắc với GET /tables/available: bàn khóa / ngừng phục vụ / đang có khách
            // mà giờ đặt nằm trong 90 phút tới thì không nhận.
            foreach ($tables as $table) {
                if ($reason = $table->unbookableReason($dateTime)) {
                    throw ValidationException::withMessages(['table_ids' => $reason]);
                }
            }

            if ($tables->sum('capacity') < $data['guest_count']) {
                throw ValidationException::withMessages(['guest_count' => "Các bàn đã chọn chỉ có {$tables->sum('capacity')} chỗ, chưa đủ cho {$data['guest_count']} khách."]);
            }

            $taken = Reservation::blocking()
                ->whereBetween('date_time', [$dateTime->copy()->subMinutes(Reservation::WINDOW_MINUTES), $dateTime->copy()->addMinutes(Reservation::WINDOW_MINUTES)])
                ->where(function ($q) use ($tableIds) {
                    foreach ($tableIds as $id) {
                        $q->orWhereJsonContains('table_ids', $id);
                    }
                })
                ->get()
                ->flatMap(fn (Reservation $r) => $r->table_ids)
                ->intersect($tableIds);

            if ($taken->isNotEmpty()) {
                $names = $tables->whereIn('id', $taken->unique()->all())->pluck('number')->join(', ');
                throw ValidationException::withMessages(['table_ids' => "{$names} đã có người đặt trong khung giờ này."]);
            }

            return Reservation::create([
                'customer_id' => $request->user()->id,
                'table_ids' => $tableIds,
                'area' => $tables->first()->area,
                'date_time' => $dateTime,
                'guest_count' => $data['guest_count'],
                'note' => $data['note'] ?? null,
                'status' => ReservationStatus::Upcoming,
                'hold_expires_at' => $request->boolean('hold') ? now()->addMinutes(self::HOLD_MINUTES) : null,
                'pre_order_items' => $lines ?: null,
                'pre_order_payment' => $lines ? $data['pre_order_payment'] : null,
            ]);
        });

        // Nếu không phải hold (đặt thẳng) → gửi thông báo xác nhận ngay
        if (! $reservation->isHeld()) {
            AppNotification::reservationConfirmed(
                $reservation->customer_id,
                $reservation->id,
                $reservation->date_time->format('H:i d/m/Y'),
            );
        }

        return $this->ok(
            ReservationResource::make($reservation),
            $reservation->isHeld() ? 'Đã giữ bàn. Vui lòng hoàn tất trong '.self::HOLD_MINUTES.' phút.' : 'Đặt bàn thành công.',
            201,
        );
    }

    /**
     * POST /api/reservations/{id}/confirm  (chủ lượt đặt)
     * Xác nhận lượt đặt đang giữ bàn, kèm món đặt trước nếu có. Gửi `pre_order_items` (kể cả mảng rỗng)
     * thì thay danh sách món đặt trước; không gửi thì giữ nguyên. Gọi lại khi đã xác nhận: trả về như cũ.
     *
     * Khi xác nhận kèm món đặt trước (pre_order_items), server tự tính và ghi nhận tiền cọc 50%.
     * Tiền cọc được lưu vào reservation.deposit_amount và deposit_paid_at = now() (giả lập đã thanh toán VietQR).
     */
    public function confirm(Request $request, Reservation $reservation): JsonResponse
    {
        if ($reservation->customer_id !== $request->user()->id) {
            return $this->fail('Bạn không có quyền xác nhận lượt đặt này.', 403);
        }

        $data = $request->validate([
            'pre_order_payment' => ['required_with:pre_order_items', 'nullable', Rule::enum(PaymentMethod::class)],
            ...LineItemBuilder::rules('pre_order_items', required: false),
            // Ở bước xác nhận cho phép mảng rỗng để xóa hết món đặt trước
            'pre_order_items' => ['nullable', 'array'],
        ]);

        Reservation::expireStale();
        $reservation->refresh();

        if ($reservation->status !== ReservationStatus::Upcoming) {
            return $this->fail('Lượt giữ bàn đã hết hạn hoặc đã bị hủy. Vui lòng đặt lại.', 422);
        }

        if (! $reservation->isHeld()) {
            return $this->ok(ReservationResource::make($reservation), 'Lượt đặt bàn đã được xác nhận.');
        }

        $update = ['hold_expires_at' => null];

        if ($request->has('pre_order_items')) {
            $lines = ! empty($data['pre_order_items']) ? $this->builder->build($data['pre_order_items'], 'pre_order_items') : [];
            $update['pre_order_items'] = $lines ?: null;
            $update['pre_order_payment'] = $lines ? $data['pre_order_payment'] : null;
        }

        // ── Tính và ghi nhận tiền cọc ─────────────────────────────────────────
        // Clone reservation và gán pre_order_items mới (nếu có) để tính đúng tổng.
        // Làm vậy vì $update chứa items mới nhưng chưa lưu DB, không thể gọi calculateDeposit()
        // trực tiếp trên $reservation (vẫn còn items cũ).
        $tempReservation = clone $reservation;
        if (isset($update['pre_order_items'])) {
            $tempReservation->pre_order_items = $update['pre_order_items'];
        }
        $depositAmount = $tempReservation->calculateDeposit();

        if ($depositAmount > 0) {
            // Ghi nhận tiền cọc và đánh dấu đã thanh toán (VietQR giả lập trong app)
            $update['deposit_amount']  = $depositAmount;
            $update['deposit_paid_at'] = now();
        } else {
            // Không có món đặt trước → xóa cọc (trường hợp khách bỏ hết món trước khi xác nhận)
            $update['deposit_amount']  = null;
            $update['deposit_paid_at'] = null;
        }

        $reservation->update($update);

        // Gửi thông báo xác nhận sau khi hoàn tất hold flow
        AppNotification::reservationConfirmed(
            $reservation->customer_id,
            $reservation->id,
            $reservation->date_time->format('H:i d/m/Y'),
        );

        return $this->ok(ReservationResource::make($reservation), 'Đặt bàn thành công.');
    }

    /**
     * GET /api/reservations?date=2026-11-12&status=upcoming  (NV Order, Thu ngân, Admin)
     *
     * Lịch đặt bàn của nhà hàng trong một ngày (mặc định hôm nay), sớm nhất trước.
     * Không gồm lượt khách còn đang giữ bàn (chưa hoàn tất 3 bước đặt bàn).
     */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'date' => ['nullable', 'date'],
            'status' => ['nullable', Rule::enum(ReservationStatus::class)],
        ]);

        Reservation::expireStale();

        // "Hôm nay" và ngày lọc tính theo giờ của quán, giống trang Lịch đặt bàn trên web /admin
        $date = isset($data['date'])
            ? Carbon::parse($data['date'])->toDateString()
            : now(config('restaurant.timezone'))->toDateString();

        $reservations = Reservation::with('customer')
            ->onRestaurantDate($date)
            ->whereNull('hold_expires_at')
            ->when(isset($data['status']), fn ($q) => $q->where('status', $data['status']))
            ->orderBy('date_time')
            ->get();

        return $this->ok($this->items($reservations, ReservationResource::class));
    }

    /**
     * POST /api/reservations/{id}/check-in  (NV Order, Thu ngân)
     *
     * Khách đặt trước đã tới quán: mở bàn, tạo đơn từ món đặt trước (gắn lượt đặt để trừ cọc
     * khi thanh toán), chuyển lượt đặt sang "Đã hoàn thành". Chi tiết: App\Services\ReservationCheckIn.
     */
    public function checkIn(Request $request, Reservation $reservation, ReservationCheckIn $checkIn): JsonResponse
    {
        $order = $checkIn->handle($reservation, $request->user());

        return $this->ok([
            'reservation' => ReservationResource::make($reservation->fresh()->load('customer'))->resolve($request),
            'order' => OrderResource::make($order->load(['table', 'customer', 'staff', 'items', 'reservation']))->resolve($request),
        ], "Đã nhận bàn cho lượt đặt {$reservation->code}.", 201);
    }

    /** GET /api/reservations/my?status= */
    public function my(Request $request): JsonResponse
    {
        $request->validate(['status' => ['nullable', Rule::enum(ReservationStatus::class)]]);

        Reservation::expireStale();

        $reservations = Reservation::where('customer_id', $request->user()->id)
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->input('status')))
            ->orderByDesc('date_time')
            ->get();

        return $this->ok($this->items($reservations, ReservationResource::class));
    }

    /**
     * PATCH /api/reservations/{id}/cancel
     *
     * - Khách hủy lượt đặt của chính mình bất cứ lúc nào khi còn "Sắp tới" (kể cả lượt đang giữ bàn).
     * - NV Order / Thu ngân / Admin hủy được mọi lượt "Sắp tới" (vd khách không đến).
     *
     * Tiền cọc KHÔNG hoàn trả. deposit_amount và deposit_paid_at được giữ nguyên trong DB
     * làm bằng chứng đối soát. Bàn không cần trả lại: trạng thái "đã đặt" của bàn được tính
     * từ các lượt đặt còn "Sắp tới", nên hủy xong bàn tự trống ở giờ đó.
     */
    public function cancel(Request $request, Reservation $reservation): JsonResponse
    {
        $user = $request->user();
        $isStaff = in_array($user->role, [UserRole::OrderStaff, UserRole::Cashier, UserRole::Admin], true);

        if (! $isStaff && $reservation->customer_id !== $user->id) {
            return $this->fail('Bạn không có quyền hủy lượt đặt này.', 403);
        }

        if ($reservation->status !== ReservationStatus::Upcoming) {
            return $this->fail('Chỉ hủy được lượt đặt đang ở trạng thái "Sắp tới".', 422);
        }

        // Hủy + giữ cọc + báo khách: cùng hàm với nút Hủy trên web /admin
        $reservation->cancelAndNotify();

        $message = $reservation->isDepositPaid()
            ? 'Đã hủy lượt đặt bàn. Tiền cọc '.number_format((float) $reservation->deposit_amount, 0, ',', '.').'đ không được hoàn lại.'
            : 'Đã hủy lượt đặt bàn.';

        return $this->ok(ReservationResource::make($reservation), $message);
    }
}
