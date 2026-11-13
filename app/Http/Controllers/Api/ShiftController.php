<?php

namespace App\Http\Controllers\Api;

use App\Enums\ShiftStatus;
use App\Models\Shift;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;

/**
 * Quản lý ca làm việc của thu ngân.
 *
 * POST   /api/shifts              - Mở ca mới (nhập tiền đầu ca)
 * GET    /api/shifts/current      - Xem ca đang mở của bản thân
 * PATCH  /api/shifts/{id}/close   - Đóng ca (nhập tiền đếm được)
 * GET    /api/shifts?date=         - Admin xem báo cáo các ca trong một ngày
 */
class ShiftController extends ApiController
{
    /**
     * GET /api/shifts?date=2026-11-12  (Admin)
     *
     * Báo cáo các ca MỞ trong một ngày (mặc định hôm nay), mới nhất trước: thu ngân, tiền đầu ca,
     * doanh thu theo phương thức, tiền mặt phải có, tiền đếm được và chênh lệch khi đóng ca.
     */
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate(['date' => ['nullable', 'date_format:Y-m-d']]);
        $date = isset($data['date']) ? Carbon::createFromFormat('Y-m-d', $data['date']) : now();

        $shifts = Shift::with('cashier')
            ->whereDate('opened_at', $date->toDateString())
            ->orderByDesc('opened_at')
            ->get()
            ->map(fn (Shift $shift) => $this->formatShift($shift))
            ->values();

        return $this->ok($shifts);
    }

    /**
     * Xem ca đang mở của thu ngân đang đăng nhập.
     * Trả về null nếu chưa mở ca.
     */
    public function current(Request $request): JsonResponse
    {
        $shift = Shift::open()
            ->where('cashier_id', $request->user()->id)
            ->first();

        if (! $shift) {
            return $this->ok(null, 'Chưa có ca nào đang mở.');
        }

        return $this->ok($this->formatShift($shift), 'Ca đang mở.');
    }

    /**
     * Mở ca mới.
     * Body: { "opening_cash": 500000 }
     */
    public function open(Request $request): JsonResponse
    {
        $data = $request->validate([
            'opening_cash' => ['required', 'numeric', 'min:0'],
        ]);

        // Kiểm tra xem thu ngân đã có ca đang mở chưa
        $existing = Shift::open()->where('cashier_id', $request->user()->id)->first();
        if ($existing) {
            throw ValidationException::withMessages([
                'shift' => 'Bạn đang có ca làm việc chưa đóng. Vui lòng đóng ca hiện tại trước.',
            ]);
        }

        $shift = Shift::create([
            'cashier_id'   => $request->user()->id,
            'status'       => ShiftStatus::Open,
            'opening_cash' => $data['opening_cash'],
            'opened_at'    => now(),
        ]);

        return $this->ok($this->formatShift($shift), 'Mở ca thành công.', 201);
    }

    /**
     * Đóng ca: nhập tiền mặt đếm được, hệ thống tính chênh lệch.
     * Body: { "closing_cash_counted": 1200000 }
     */
    public function close(Request $request, Shift $shift): JsonResponse
    {
        // Chỉ được đóng ca của chính mình
        if ($shift->cashier_id !== $request->user()->id) {
            return $this->fail('Bạn không có quyền đóng ca này.', 403);
        }
        if (! $shift->isOpen()) {
            throw ValidationException::withMessages(['shift' => 'Ca này đã đóng.']);
        }

        $data = $request->validate([
            'closing_cash_counted' => ['required', 'numeric', 'min:0'],
        ]);

        $shift->update([
            'status'               => ShiftStatus::Closed,
            'closing_cash_counted' => $data['closing_cash_counted'],
            'closed_at'            => now(),
        ]);

        return $this->ok($this->formatShift($shift->fresh()), 'Đóng ca thành công.');
    }

    /* ── Helper ───────────────────────────────────────── */

    private function formatShift(Shift $shift): array
    {
        $expectedCash     = $shift->expectedCash();
        $countedCash      = $shift->closing_cash_counted !== null ? (float) $shift->closing_cash_counted : null;
        $cashDifference   = $shift->cashDifference();

        // Doanh thu theo phương thức: cùng hàm với trang Báo cáo ca trên web /admin
        $byMethod = $shift->revenueByMethod();
        $invoiceCount = $shift->invoices()->count();
        $totalRevenue = array_sum($byMethod);

        return [
            'id'                    => $shift->id,
            'cashier_id'            => $shift->cashier_id,
            'cashier_name'          => $shift->cashier?->name ?? '',
            'status'                => $shift->status->value,
            'opening_cash'          => (float) $shift->opening_cash,
            'closing_cash_counted'  => $countedCash,
            'expected_cash'         => $expectedCash,
            'cash_difference'       => $cashDifference,
            'revenue_by_method'     => $byMethod,
            'total_revenue'         => $totalRevenue,
            'invoice_count'         => $invoiceCount,
            'opened_at'             => $shift->opened_at?->toIso8601String(),
            'closed_at'             => $shift->closed_at?->toIso8601String(),
        ];
    }
}
