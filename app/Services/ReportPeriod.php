<?php

namespace App\Services;

use App\Models\Invoice;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;

/**
 * Kỳ báo cáo khi xuất Excel: một NGÀY, một THÁNG hoặc một NĂM — tính theo giờ của quán
 * (config restaurant.timezone), trong khi database lưu giờ UTC.
 * Dùng chung cho web /admin (nút Xuất báo cáo Excel) và app Admin (GET /reports/export-*),
 * nên hai nơi luôn cho cùng lựa chọn và cùng một file.
 *
 * Nhóm chốt 13/11: chỉ cho chọn những tháng / năm ĐÃ CÓ doanh thu; ngày thì chọn ngày bất kỳ
 * từ trước tới hôm nay.
 */
final class ReportPeriod
{
    public const TYPES = ['day' => 'Ngày', 'month' => 'Tháng', 'year' => 'Năm'];

    private function __construct(
        public readonly string $type,
        public readonly string $value,
        /** Đầu kỳ, giờ của quán. */
        public readonly Carbon $start,
        /** Hết kỳ (không tính), giờ của quán. */
        public readonly Carbon $end,
        public readonly string $label,
    ) {}

    /**
     * @param  string  $type  day | month | year
     * @param  string  $value  Y-m-d | Y-m | Y
     *
     * @throws ValidationException
     */
    public static function make(string $type, string $value): self
    {
        $tz = config('restaurant.timezone');
        $value = trim($value);

        switch ($type) {
            case 'day':
                $start = self::parse('Y-m-d', $value, $tz, 'Ngày không hợp lệ.');
                if ($start->gt(now($tz)->startOfDay())) {
                    self::fail('Không xuất được báo cáo cho ngày trong tương lai.');
                }

                return new self('day', $start->format('Y-m-d'), $start, $start->copy()->addDay(), 'Ngày '.$start->format('d/m/Y'));

            case 'month':
                if (! array_key_exists($value, self::availableMonths())) {
                    self::fail('Tháng này chưa có doanh thu để xuất.');
                }
                $start = self::parse('Y-m', $value, $tz, 'Tháng không hợp lệ.')->startOfMonth();

                return new self('month', $value, $start, $start->copy()->addMonth(), 'Tháng '.$start->format('m/Y'));

            case 'year':
                if (! array_key_exists($value, self::availableYears())) {
                    self::fail('Năm này chưa có doanh thu để xuất.');
                }
                $start = self::parse('Y', $value, $tz, 'Năm không hợp lệ.')->startOfYear();

                return new self('year', $value, $start, $start->copy()->addYear(), 'Năm '.$start->format('Y'));
        }

        self::fail('Kỳ báo cáo phải là ngày, tháng hoặc năm.');
    }

    /** Đầu kỳ đổi sang múi giờ lưu trong database (để so sánh với paid_at). */
    public function startForDb(): Carbon
    {
        return $this->start->copy()->setTimezone(config('app.timezone'));
    }

    public function endForDb(): Carbon
    {
        return $this->end->copy()->setTimezone(config('app.timezone'));
    }

    /** Tên file tải về, vd bao-cao-dineflow_thang-2026-11.xlsx */
    public function fileName(): string
    {
        $prefix = ['day' => 'ngay', 'month' => 'thang', 'year' => 'nam'][$this->type];

        return "bao-cao-dineflow_{$prefix}-{$this->value}.xlsx";
    }

    /** Các tháng có hóa đơn đã thanh toán, mới nhất trước: ['2026-11' => 'Tháng 11/2026', ...]. */
    public static function availableMonths(): array
    {
        return self::paidMoments()
            ->mapWithKeys(fn (Carbon $at) => [$at->format('Y-m') => 'Tháng '.$at->format('m/Y')])
            ->sortKeysDesc()
            ->all();
    }

    /** Các năm có hóa đơn đã thanh toán, mới nhất trước: ['2026' => 'Năm 2026', ...]. */
    public static function availableYears(): array
    {
        return self::paidMoments()
            ->mapWithKeys(fn (Carbon $at) => [$at->format('Y') => 'Năm '.$at->format('Y')])
            ->sortKeysDesc()
            ->all();
    }

    /** Thời điểm thanh toán của mọi hóa đơn, đổi sang giờ của quán. */
    private static function paidMoments(): \Illuminate\Support\Collection
    {
        $tz = config('restaurant.timezone');

        return Invoice::paid()
            ->whereNotNull('paid_at')
            ->pluck('paid_at')
            ->map(fn ($at) => Carbon::parse($at)->setTimezone($tz));
    }

    private static function parse(string $format, string $value, string $tz, string $message): Carbon
    {
        try {
            $date = Carbon::createFromFormat('!'.$format, $value, $tz);
        } catch (\Throwable) {
            $date = false;
        }
        if (! $date || $date->format($format) !== $value) {
            self::fail($message);
        }

        return $date;
    }

    /** @throws ValidationException */
    private static function fail(string $message): never
    {
        throw ValidationException::withMessages(['period' => $message]);
    }
}
