<?php

namespace App\Http\Controllers\Api;

use App\Enums\ShiftStatus;
use App\Models\Shift;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Quản lý ca làm việc của thu ngân.
 *
 * POST   /api/shifts              - Mở ca mới (nhập tiền đầu ca)
 * GET    /api/shifts/current      - Xem ca đang mở của bản thân
 * PATCH  /api/shifts/{id}/close   - Đóng ca (nhập tiền đếm được)
 */
class ShiftController extends ApiController
{
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
        $cashDifference   = $countedCash !== null ? $countedCash - $expectedCash : null;

        // Thống kê doanh thu theo phương thức
        $invoices = $shift->invoices()->get(['payment_method', 'total']);
        $byMethod = [];
        foreach (['cash', 'qr', 'card'] as $method) {
            $byMethod[$method] = (float) $invoices->where('payment_method', $method)->sum('total');
        }
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
            'invoice_count'         => $invoices->count(),
            'opened_at'             => $shift->opened_at?->toIso8601String(),
            'closed_at'             => $shift->closed_at?->toIso8601String(),
        ];
    }
}
