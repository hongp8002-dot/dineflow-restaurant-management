<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Khuôn phản hồi chung cho mọi API: { status, message, data, meta? }
 * status = "success" | "error".
 */
abstract class ApiController extends Controller
{
    protected function ok(mixed $data = null, string $message = 'Thành công', int $code = 200, array $meta = []): JsonResponse
    {
        if ($data instanceof JsonResource) {
            $data = $data->resolve(request());
        }

        $body = ['status' => 'success', 'message' => $message, 'data' => $data];
        if ($meta) {
            $body['meta'] = $meta;
        }

        return response()->json($body, $code);
    }

    protected function fail(string $message, int $code = 422, ?array $errors = null): JsonResponse
    {
        $body = ['status' => 'error', 'message' => $message, 'data' => null];
        if ($errors !== null) {
            $body['errors'] = $errors;
        }

        return response()->json($body, $code);
    }

    /**
     * Biến danh sách model thành mảng JSON qua Resource.
     * (Resolve từng phần tử để các quan hệ lồng nhau được xử lý đầy đủ.)
     *
     * @param  iterable<mixed>  $models
     * @param  class-string<JsonResource>  $resource
     */
    protected function items(iterable $models, string $resource): array
    {
        return collect($models)
            ->map(fn ($model) => $resource::make($model)->resolve(request()))
            ->values()
            ->all();
    }
}
