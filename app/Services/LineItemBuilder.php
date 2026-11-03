<?php

namespace App\Services;

use App\Enums\FoodOptionGroup;
use App\Models\Food;
use Illuminate\Validation\ValidationException;

/**
 * Dựng các dòng món (đơn hàng / món đặt trước) từ dữ liệu client gửi lên.
 *
 * Client chỉ gửi food_id, quantity, option_ids. Tên món, đơn giá và phụ thu
 * luôn lấy từ database, không bao giờ tin giá do client gửi.
 */
class LineItemBuilder
{
    /**
     * @param  array<int, array{food_id: int, quantity: int, option_ids?: array<int>, note?: ?string}>  $items
     * @return array<int, array{food_id: int, food_name: string, quantity: int, price: float, options: array, note: ?string}>
     *
     * @throws ValidationException
     */
    public function build(array $items, string $field = 'items'): array
    {
        $foods = Food::with('options')
            ->whereIn('id', collect($items)->pluck('food_id')->unique()->all())
            ->get()
            ->keyBy('id');

        $lines = [];

        foreach (array_values($items) as $i => $item) {
            /** @var Food|null $food */
            $food = $foods->get((int) $item['food_id']);

            if (! $food) {
                throw ValidationException::withMessages(["{$field}.{$i}.food_id" => 'Món không tồn tại.']);
            }

            if (! $food->is_available) {
                throw ValidationException::withMessages(["{$field}.{$i}.food_id" => "Món \"{$food->name}\" hiện không phục vụ."]);
            }

            $optionIds = collect($item['option_ids'] ?? [])->map(fn ($id) => (int) $id)->unique()->values();
            $options = $food->options->whereIn('id', $optionIds->all())->values();

            if ($options->count() !== $optionIds->count()) {
                throw ValidationException::withMessages(["{$field}.{$i}.option_ids" => "Tùy chọn không hợp lệ cho món \"{$food->name}\"."]);
            }

            if ($options->where('group', FoodOptionGroup::Size)->count() > 1) {
                throw ValidationException::withMessages(["{$field}.{$i}.option_ids" => "Món \"{$food->name}\" chỉ được chọn một size."]);
            }

            $lines[] = [
                'food_id' => $food->id,
                'food_name' => $food->name,
                'quantity' => (int) $item['quantity'],
                'price' => (float) $food->price,
                'options' => $options->map->toSnapshot()->all(),
                'note' => $item['note'] ?? null,
            ];
        }

        return $lines;
    }

    /** Quy tắc validate dùng chung cho mảng món trong request. */
    public static function rules(string $field = 'items', bool $required = true): array
    {
        return [
            $field => [$required ? 'required' : 'nullable', 'array', 'min:1'],
            "{$field}.*.food_id" => ['required', 'integer', 'exists:foods,id'],
            "{$field}.*.quantity" => ['required', 'integer', 'min:1', 'max:99'],
            "{$field}.*.option_ids" => ['sometimes', 'array'],
            "{$field}.*.option_ids.*" => ['integer'],
            "{$field}.*.note" => ['nullable', 'string', 'max:255'],
        ];
    }
}
