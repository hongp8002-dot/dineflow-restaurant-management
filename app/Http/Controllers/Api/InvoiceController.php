<?php

namespace App\Http\Controllers\Api;

use App\Http\Resources\InvoiceResource;
use App\Models\Invoice;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class InvoiceController extends ApiController
{
    /**
     * GET /api/invoices?date=2025-01-31&mine=1&per_page=50  (thu ngân, admin)
     * Hóa đơn đã thanh toán, mới nhất trước. `mine=1` chỉ lấy hóa đơn do chính người đang đăng nhập thu.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'date' => ['nullable', 'date'],
            'mine' => ['nullable', 'boolean'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $invoices = Invoice::paid()
            ->with(['order.table', 'order.items', 'cashier', 'promotion'])
            ->when($request->filled('date'), fn ($q) => $q->whereDate('paid_at', $request->date('date')))
            ->when($request->boolean('mine'), fn ($q) => $q->where('cashier_id', $request->user()->id))
            ->orderByDesc('paid_at')
            ->orderByDesc('id')
            ->paginate($request->integer('per_page', 50));

        return $this->ok($this->items($invoices->items(), InvoiceResource::class), 'Thành công', 200, [
            'current_page' => $invoices->currentPage(),
            'last_page' => $invoices->lastPage(),
            'per_page' => $invoices->perPage(),
            'total' => $invoices->total(),
        ]);
    }
}
