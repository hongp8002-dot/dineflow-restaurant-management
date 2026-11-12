<?php

namespace App\Http\Controllers\Api;

use App\Models\AppNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Thông báo in-app của khách hàng.
 *
 * GET  /api/customers/me/notifications           – danh sách (mới nhất trước)
 * PATCH /api/customers/me/notifications/{id}/read – đánh dấu 1 thông báo đã đọc
 * POST  /api/customers/me/notifications/read-all  – đánh dấu tất cả đã đọc
 */
class NotificationController extends ApiController
{
    /** GET /api/customers/me/notifications */
    public function index(Request $request): JsonResponse
    {
        $notifications = AppNotification::where('customer_id', $request->user()->id)
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (AppNotification $n) => [
                'id'         => $n->id,
                'type'       => $n->type,
                'title'      => $n->title,
                'body'       => $n->body,
                'data'       => $n->data,
                'read'       => $n->read_at !== null,
                'created_at' => $n->created_at->toIso8601String(),
            ]);

        return $this->ok($notifications);
    }

    /** PATCH /api/customers/me/notifications/{id}/read */
    public function markRead(Request $request, int $id): JsonResponse
    {
        $notification = AppNotification::where('customer_id', $request->user()->id)
            ->findOrFail($id);

        if ($notification->read_at === null) {
            $notification->update(['read_at' => now()]);
        }

        return $this->ok(null, 'Đã đánh dấu đã đọc.');
    }

    /** POST /api/customers/me/notifications/read-all */
    public function markAllRead(Request $request): JsonResponse
    {
        AppNotification::where('customer_id', $request->user()->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return $this->ok(null, 'Đã đánh dấu tất cả đã đọc.');
    }
}
