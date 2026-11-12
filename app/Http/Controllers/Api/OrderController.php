<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Enums\PaymentStatus;
use App\Enums\UserRole;
use App\Http\Resources\OrderResource;
use App\Models\DiningTable;
use App\Models\Order;
use App\Services\LineItemBuilder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class OrderController extends ApiController
{
    // 'reservation' được load để OrderResource có thể đọc deposit_amount từ đặt bàn kèm món.
    private const RELATIONS = ['table', 'customer', 'staff', 'items', 'reservation'];

    public function __construct(private LineItemBuilder $builder) {}

    /**
     * GET /api/orders?status=placed,preparing&payment_status=&table_id=&date=2025-01-31&open=1
     * Nhân viên / thu ngân / admin thấy tất cả; khách hàng chỉ thấy đơn của mình.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'status' => ['nullable', 'string'],
            'payment_status' => ['nullable', Rule::enum(PaymentStatus::class)],
            'table_id' => ['nullable', 'integer'],
            'date' => ['nullable', 'date'],
            'open' => ['nullable', 'boolean'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $statuses = collect(explode(',', (string) $request->input('status')))
            ->map(fn ($s) => OrderStatus::tryFrom(trim($s)))
            ->filter();

        $orders = Order::with(self::RELATIONS)
            ->when($request->user()->role === UserRole::Customer, fn ($q) => $q->where('customer_id', $request->user()->id))
            ->when($statuses->isNotEmpty(), fn ($q) => $q->whereIn('status', $statuses->all()))
            ->when($request->filled('payment_status'), fn ($q) => $q->where('payment_status', $request->input('payment_status')))
            ->when($request->filled('table_id'), fn ($q) => $q->where('table_id', $request->integer('table_id')))
            ->when($request->filled('date'), fn ($q) => $q->whereDate('created_at', $request->date('date')))
            ->when($request->boolean('open'), fn ($q) => $q->open())
            ->latest()
            ->paginate($request->integer('per_page', 50));

        return $this->ok($this->items($orders->items(), OrderResource::class), 'Thành công', 200, [
            'current_page' => $orders->currentPage(),
            'last_page' => $orders->lastPage(),
            'per_page' => $orders->perPage(),
            'total' => $orders->total(),
        ]);
    }

    public function show(Request $request, Order $order): JsonResponse
    {
        if ($this->isForeignCustomerOrder($request, $order)) {
            return $this->fail('Bạn không có quyền xem đơn này.', 403);
        }

        return $this->ok(OrderResource::make($order->load(self::RELATIONS)));
    }

    /**
     * POST /api/orders
     *
     * Nhân viên: bắt buộc có table_id. Nếu bàn đang có đơn mở, các món mới được THÊM vào đơn đó
     * (một bàn chỉ có một đơn mở) và đơn quay về "placed" nếu đã ra món để bếp làm tiếp.
     * Khách hàng: tạo đơn không gắn bàn, customer_id là chính khách.
     */
    public function store(Request $request): JsonResponse
    {
        $user = $request->user();
        $isCustomer = $user->role === UserRole::Customer;

        $data = $request->validate([
            'table_id' => ['nullable', 'integer', 'exists:tables,id'],
            'customer_id' => ['nullable', 'integer', 'exists:users,id'],
            'note' => ['nullable', 'string', 'max:500'],
            ...LineItemBuilder::rules('items'),
        ]);

        if (! $isCustomer && empty($data['table_id'])) {
            throw ValidationException::withMessages(['table_id' => 'Vui lòng chọn bàn cho đơn hàng.']);
        }

        $lines = $this->builder->build($data['items']);
        $tableId = $isCustomer ? null : ($data['table_id'] ?? null);

        [$order, $appended] = DB::transaction(function () use ($data, $lines, $user, $isCustomer, $tableId) {
            $table = $tableId ? DiningTable::lockForUpdate()->findOrFail($tableId) : null;
            $order = null;
            $appended = false;

            // Bàn đang có đơn mở chưa thanh toán -> gọi thêm vào đơn đó
            if ($table?->current_order_id) {
                $existing = Order::lockForUpdate()->find($table->current_order_id);
                if ($existing && $existing->status->isOpen() && ! $existing->isPaid()) {
                    $order = $existing;
                    $appended = true;
                }
            }

            $order ??= Order::create([
                'table_id' => $tableId,
                'customer_id' => $isCustomer ? $user->id : ($data['customer_id'] ?? null),
                'staff_id' => $isCustomer ? null : $user->id,
                'status' => OrderStatus::Placed,
                'payment_status' => PaymentStatus::Unpaid,
                'note' => $data['note'] ?? null,
            ]);

            $order->items()->createMany($lines);

            if ($appended) {
                if ($order->status === OrderStatus::Serving) {
                    $order->status = OrderStatus::Placed;
                }
                if (! empty($data['note'])) {
                    $order->note = trim($order->note."\n".$data['note']);
                }
            }

            $order->recalculateTotal();

            if ($table && ! $appended) {
                $table->occupy($order);
            }

            return [$order, $appended];
        });

        return $this->ok(
            OrderResource::make($order->load(self::RELATIONS)),
            $appended ? 'Đã thêm món vào đơn hiện tại của bàn.' : 'Tạo đơn hàng thành công.',
            $appended ? 200 : 201,
        );
    }

    /** PATCH /api/orders/{id}/status  body: { "status": "preparing" } */
    public function updateStatus(Request $request, Order $order): JsonResponse
    {
        $data = $request->validate(['status' => ['required', Rule::enum(OrderStatus::class)]]);
        $to = OrderStatus::from($data['status']);

        if (! $order->status->canTransitionTo($to)) {
            return $this->fail("Không thể chuyển đơn từ \"{$order->status->getLabel()}\" sang \"{$to->getLabel()}\".", 422);
        }

        if ($to === OrderStatus::Cancelled && $order->isPaid()) {
            return $this->fail('Đơn đã thanh toán, không thể hủy.', 422);
        }

        $order->update(['status' => $to]);
        $order->releaseTableIfDone();

        return $this->ok(OrderResource::make($order->load(self::RELATIONS)), "Đơn {$order->code}: {$to->getLabel()}.");
    }

    private function isForeignCustomerOrder(Request $request, Order $order): bool
    {
        return $request->user()->role === UserRole::Customer && $order->customer_id !== $request->user()->id;
    }
}
