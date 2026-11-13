<?php

namespace App\Http\Controllers\Api;

use App\Services\ReportExporter;
use App\Services\ReportPeriod;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\URL;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Xuất báo cáo Excel cho app Admin (web /admin dùng cùng ReportPeriod + ReportExporter).
 *
 *   GET  /api/reports/export-periods   (Admin) → các tháng / năm có doanh thu để chọn
 *   POST /api/reports/export-link      (Admin) { type: day|month|year, value } → link tải 5 phút
 *   GET  /api/reports/export/download  (link có chữ ký, không cần token) → file .xlsx
 *
 * App mở link bằng trình duyệt (url_launcher có sẵn) để tải file, nên không phải cài thêm thư viện
 * lưu file. Link có chữ ký: hết hạn sau 5 phút, sửa tham số là bị từ chối (403).
 */
class ReportExportController extends ApiController
{
    private const LINK_MINUTES = 5;

    public function periods(): JsonResponse
    {
        $toList = fn (array $map) => collect($map)->map(fn ($label, $value) => ['value' => (string) $value, 'label' => $label])->values();

        return $this->ok([
            'months' => $toList(ReportPeriod::availableMonths()),
            'years' => $toList(ReportPeriod::availableYears()),
            'today' => now(config('restaurant.timezone'))->toDateString(),
        ]);
    }

    public function link(Request $request): JsonResponse
    {
        $data = $request->validate([
            'type' => ['required', Rule::in(array_keys(ReportPeriod::TYPES))],
            'value' => ['required', 'string', 'max:10'],
        ], ['type.in' => 'Kỳ báo cáo phải là ngày, tháng hoặc năm.']);

        $period = ReportPeriod::make($data['type'], $data['value']); // kiểm tra trước khi phát link

        $url = URL::temporarySignedRoute(
            'reports.export.download',
            now()->addMinutes(self::LINK_MINUTES),
            ['type' => $period->type, 'value' => $period->value],
        );

        return $this->ok([
            'url' => $url,
            'file_name' => $period->fileName(),
            'label' => $period->label,
            'expires_in' => self::LINK_MINUTES * 60,
        ], "Đã tạo link tải báo cáo {$period->label}.");
    }

    public function download(Request $request, ReportExporter $exporter): BinaryFileResponse
    {
        $period = ReportPeriod::make((string) $request->query('type'), (string) $request->query('value'));

        return $exporter->download($period);
    }
}
