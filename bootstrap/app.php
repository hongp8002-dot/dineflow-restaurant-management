<?php

use App\Http\Middleware\EnsureUserHasRole;
use App\Http\Middleware\EnsureUserIsActive;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->alias([
            'role' => EnsureUserHasRole::class,
            'active' => EnsureUserIsActive::class,
        ]);

        // Chưa đăng nhập: API trả 401 JSON (không redirect); web chuyển tới trang đăng nhập Filament
        $middleware->redirectGuestsTo(fn (Request $request) => $request->is('api/*') ? null : route('filament.admin.auth.login'));
    })
    ->withExceptions(function (Exceptions $exceptions) {
        // Mọi request /api/* luôn trả JSON, kể cả khi client quên header Accept
        $exceptions->shouldRenderJsonWhen(fn (Request $request) => $request->is('api/*') || $request->expectsJson());

        // Lỗi API cùng một khuôn: { status: "error", message, data: null, errors? }
        $error = function (string $message, int $code, ?array $errors = null) {
            $body = ['status' => 'error', 'message' => $message, 'data' => null];
            if ($errors !== null) {
                $body['errors'] = $errors;
            }

            return response()->json($body, $code);
        };

        $exceptions->render(function (ValidationException $e, Request $request) use ($error) {
            if ($request->is('api/*')) {
                return $error($e->validator->errors()->first() ?: 'Dữ liệu không hợp lệ.', 422, $e->errors());
            }
        });

        $exceptions->render(function (AuthenticationException $e, Request $request) use ($error) {
            if ($request->is('api/*')) {
                return $error('Chưa đăng nhập hoặc token không hợp lệ.', 401);
            }
        });

        $exceptions->render(function (ModelNotFoundException|NotFoundHttpException $e, Request $request) use ($error) {
            if ($request->is('api/*')) {
                return $error('Không tìm thấy dữ liệu yêu cầu.', 404);
            }
        });

        $exceptions->render(function (HttpExceptionInterface $e, Request $request) use ($error) {
            if ($request->is('api/*')) {
                $message = match ($e->getStatusCode()) {
                    403 => $e->getMessage() ?: 'Bạn không có quyền thực hiện thao tác này.',
                    405 => 'Phương thức không được hỗ trợ.',
                    429 => 'Thao tác quá nhanh, vui lòng thử lại sau.',
                    default => $e->getMessage() ?: 'Đã có lỗi xảy ra.',
                };

                return $error($message, $e->getStatusCode());
            }
        });
    })->create();
