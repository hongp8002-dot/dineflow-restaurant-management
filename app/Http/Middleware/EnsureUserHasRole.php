<?php

namespace App\Http\Middleware;

use App\Enums\UserRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Giới hạn route theo vai trò. Dùng: ->middleware('role:cashier,admin')
 */
class EnsureUserHasRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $allowed = array_map(fn (string $r) => UserRole::from($r), $roles);

        if (! $request->user()?->hasRole(...$allowed)) {
            abort(403, 'Vai trò của bạn không được phép thực hiện thao tác này.');
        }

        return $next($request);
    }
}
