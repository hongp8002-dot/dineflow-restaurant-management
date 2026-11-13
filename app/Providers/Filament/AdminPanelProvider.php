<?php

namespace App\Providers\Filament;

use Filament\Forms\Components\DateTimePicker;
use Filament\Http\Middleware\Authenticate;
use Filament\Http\Middleware\AuthenticateSession;
use Filament\Http\Middleware\DisableBladeIconComponents;
use Filament\Http\Middleware\DispatchServingFilamentEvent;
use Filament\Pages;
use Filament\Panel;
use Filament\PanelProvider;
use Filament\Infolists\Components\TextEntry;
use Filament\Support\Colors\Color;
use Filament\Tables\Columns\TextColumn;
use Filament\Widgets;
use Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse;
use Illuminate\Cookie\Middleware\EncryptCookies;
use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken;
use Illuminate\Routing\Middleware\SubstituteBindings;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\View\Middleware\ShareErrorsFromSession;

class AdminPanelProvider extends PanelProvider
{
    /**
     * Database lưu giờ UTC; web /admin hiển thị và nhập giờ theo múi giờ của quán
     * (config restaurant.timezone, mặc định Asia/Ho_Chi_Minh) để khớp với giờ trên app.
     * Chỉ áp cho cột / ô có GIỜ: ô chọn chỉ ngày (DatePicker) không đổi múi giờ để không lệch ngày.
     */
    public function boot(): void
    {
        $timezone = config('restaurant.timezone');

        TextColumn::configureUsing(fn (TextColumn $column) => $column->timezone($timezone));
        TextEntry::configureUsing(fn (TextEntry $entry) => $entry->timezone($timezone));
        DateTimePicker::configureUsing(function (DateTimePicker $picker) use ($timezone): void {
            // DatePicker kế thừa DateTimePicker: chỉ đổi múi giờ khi ô có chọn giờ
            $picker->timezone(fn (DateTimePicker $component): ?string => $component->hasTime() ? $timezone : null);
        });
    }

    public function panel(Panel $panel): Panel
    {
        return $panel
            ->default()
            ->id('admin')
            ->path('admin')
            ->login()
            ->brandName('DineFlow Admin')
            ->colors([
                'primary' => Color::Amber,
            ])
            ->discoverResources(in: app_path('Filament/Resources'), for: 'App\\Filament\\Resources')
            ->discoverPages(in: app_path('Filament/Pages'), for: 'App\\Filament\\Pages')
            ->pages([
                Pages\Dashboard::class,
            ])
            ->discoverWidgets(in: app_path('Filament/Widgets'), for: 'App\\Filament\\Widgets')
            ->widgets([
                Widgets\AccountWidget::class,
            ])
            ->middleware([
                EncryptCookies::class,
                AddQueuedCookiesToResponse::class,
                StartSession::class,
                AuthenticateSession::class,
                ShareErrorsFromSession::class,
                VerifyCsrfToken::class,
                SubstituteBindings::class,
                DisableBladeIconComponents::class,
                DispatchServingFilamentEvent::class,
            ])
            ->authMiddleware([
                Authenticate::class,
            ]);
    }
}
