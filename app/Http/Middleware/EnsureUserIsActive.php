<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Chặn tài khoản đã bị admin khóa, kể cả khi token cũ còn sót lại. */
class EnsureUserIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && ! $user->isActive()) {
            $user->currentAccessToken()?->delete();

            abort(403, 'Tài khoản của bạn đã bị khóa.');
        }

        return $next($request);
    }
}
