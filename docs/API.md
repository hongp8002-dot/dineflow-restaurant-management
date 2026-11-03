# DineFlow Backend – Hướng dẫn chạy và test API

## 1. Chạy server

```bat
cd dineflow_backend
php artisan serve
```

| Việc | Địa chỉ |
|---|---|
| Web Admin (Filament) | http://127.0.0.1:8000/admin |
| API | http://127.0.0.1:8000/api |

Đặt lại toàn bộ dữ liệu mẫu bất cứ lúc nào: `php artisan migrate:fresh --seed`

**App Flutter gọi API thế nào:**

| Chạy app trên | Base URL |
|---|---|
| Android Emulator | `http://10.0.2.2:8000/api` |
| iOS Simulator / Windows / Web | `http://127.0.0.1:8000/api` |
| Điện thoại thật (cùng Wi-Fi) | `http://<IP máy tính>:8000/api`, chạy server bằng `php artisan serve --host=0.0.0.0` |

> Điện thoại thật: nếu không kết nối được, kiểm tra Windows Firewall có chặn cổng 8000 không.

## 2. Tài khoản mẫu (mật khẩu `123456`)

| Vai trò | Email | Làm được gì |
|---|---|---|
| Admin | admin@dineflow.com | Vào `/admin`, dùng được mọi API |
| Nhân viên order | staff@dineflow.com | Tạo đơn, đổi trạng thái đơn |
| Thu ngân | cashier@dineflow.com | Đổi trạng thái đơn, thanh toán |
| Khách hàng | customer@dineflow.com | Đặt bàn, tự đặt món, xem đơn của mình |
| (bị khóa) | locked@dineflow.com | Dùng để thử đăng nhập bị từ chối |

## 3. Định dạng phản hồi

```json
{ "status": "success", "message": "Thành công", "data": { } }
```
Lỗi:
```json
{ "status": "error", "message": "Chỉ có thông báo đầu tiên", "data": null, "errors": { "field": ["..."] } }
```

| Mã HTTP | Ý nghĩa |
|---|---|
| 200 / 201 | Thành công / đã tạo |
| 401 | Chưa đăng nhập, token sai hoặc đã đăng xuất |
| 403 | Sai vai trò, hoặc tài khoản bị khóa |
| 404 | Không tìm thấy |
| 422 | Dữ liệu không hợp lệ hoặc vi phạm quy tắc nghiệp vụ (xem `message`) |
| 429 | Gọi login quá nhanh (tối đa 10 lần/phút) |

Mọi request ngoài login/register cần header `Authorization: Bearer <token>`.
Nên luôn gửi `Accept: application/json`.

## 4. Test bằng Postman (khuyên dùng)

1. Postman → **Import** → chọn [DineFlow.postman_collection.json](DineFlow.postman_collection.json).
2. Mở folder **1. Xác thực** → chạy một request **Đăng nhập** (vd. Nhân viên order). Token tự được lưu và gắn vào mọi request sau.
3. Thử theo thứ tự: **Tạo đơn tại Bàn 1** (tự lưu `orderId`) → **Đổi trạng thái** → đăng nhập **Thu ngân** → **Thanh toán**.
4. Muốn thử vai trò khác thì chạy lại request Đăng nhập tương ứng.

Đổi biến `baseUrl` của collection nếu bạn không chạy ở `127.0.0.1:8000`.

## 5. Test bằng curl

Các lệnh dưới viết cho **Git Bash** (dấu nháy đơn quanh JSON). Trên `cmd`/PowerShell nên dùng Postman cho gọn.

```bash
B=http://127.0.0.1:8000/api
H='Accept: application/json'

# Đăng nhập, lấy token
curl -s -X POST $B/login -H "$H" -H 'Content-Type: application/json' \
  -d '{"email":"staff@dineflow.com","password":"123456"}'
TOKEN=<dán token vào đây>

# Thực đơn danh mục 1, và danh sách bàn
curl -s "$B/foods?category_id=1" -H "$H" -H "Authorization: Bearer $TOKEN"
curl -s "$B/tables"              -H "$H" -H "Authorization: Bearer $TOKEN"

# Tạo đơn tại Bàn 1: 2 Cà phê sữa đá (food 1) size M (option 2)
curl -s -X POST $B/orders -H "$H" -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  -d '{"table_id":1,"note":"Ít đá","items":[{"food_id":1,"quantity":2,"option_ids":[2]}]}'

# Đổi trạng thái đơn (thay 12 bằng id đơn vừa tạo)
curl -s -X PATCH $B/orders/12/status -H "$H" -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN" \
  -d '{"status":"preparing"}'

# Thu ngân thanh toán có mã giảm giá (đăng nhập cashier@ để lấy token khác)
curl -s -X POST $B/orders/12/pay -H "$H" -H 'Content-Type: application/json' -H "Authorization: Bearer $CASHIER_TOKEN" \
  -d '{"payment_method":"qr","promotion_code":"WELCOME10"}'
```

Kết quả mong đợi của luồng trên: đơn 2 × (29.000 + 8.000) = **74.000**, giảm WELCOME10 **7.400**, tổng **66.600**, Bàn 1 về `empty`.

## 6. Danh sách endpoint

| Method | Đường dẫn | Vai trò | Body / query chính |
|---|---|---|---|
| POST | `/login` | công khai | `login` (**số điện thoại hoặc email**; số điện thoại gõ kiểu `0900 000.002` cũng được) hoặc `email` (cách cũ), `password`, `device_name?` |
| POST | `/register` | công khai | `name`, `email`, `phone?`, `password` (≥ 6 ký tự). Luôn tạo **khách hàng** |
| POST | `/logout` | đã đăng nhập | |
| GET | `/me` | đã đăng nhập | |
| PATCH | `/me/password` | đã đăng nhập | Body: `current_password`, `password`, `password_confirmation` (≥ 6 ký tự, khác mật khẩu cũ). Sai mật khẩu hiện tại → 422. Thành công thì các token khác của tài khoản bị thu hồi. |
| GET | `/categories` | đã đăng nhập | |
| GET | `/foods` | đã đăng nhập | `category_id`, `search`, `available=1`, `best_seller=1`. Kèm `options` (size/topping) |
| GET | `/promotions` | đã đăng nhập | Voucher đang hiệu lực |
| GET | `/tables` | đã đăng nhập | `area`, `status` (`empty`/`serving`/`reserved`) |
| POST | `/reservations` | khách hàng | `table_ids[]`, `date_time` (ISO 8601; giờ UTC "...Z" cũng được, server đổi về múi giờ quán), `guest_count`, `note?`, `hold?`, `pre_order_items[]?`, `pre_order_payment` (`cash`/`qr`/`card`, bắt buộc nếu có món). `hold=true`: chỉ **giữ bàn 10 phút**, chờ xác nhận |
| POST | `/reservations/{id}/confirm` | chủ lượt đặt (khách) | `pre_order_items[]?` (gửi mảng rỗng để xóa món đặt trước, không gửi để giữ nguyên), `pre_order_payment`. Xác nhận lượt đang giữ bàn; gọi lại khi đã xác nhận thì trả về như cũ |
| GET | `/reservations/my` | đã đăng nhập | `status?` |
| PATCH | `/reservations/{id}/cancel` | chủ lượt đặt | |
| GET | `/orders` | đã đăng nhập | `status=a,b`, `payment_status`, `table_id`, `date`, `open=1`, `per_page`. Khách chỉ thấy đơn của mình |
| GET | `/orders/{id}` | đã đăng nhập | |
| POST | `/orders` | nhân viên order, admin, khách | `table_id` (bắt buộc với nhân viên), `note?`, `items[]` |
| PATCH | `/orders/{id}/status` | nhân viên order, thu ngân, admin | `status`: `placed` `preparing` `serving` `completed` `cancelled` |
| POST | `/orders/{id}/pay` | thu ngân, admin | `payment_method`, `promotion_code?`, `points_used?` (dùng điểm thưởng của khách, 1 điểm = 1đ) |
| GET | `/invoices` | thu ngân, admin | `date=YYYY-MM-DD`, `mine=1` (chỉ hóa đơn do mình thu), `per_page`. Hóa đơn đã thanh toán, mới nhất trước |
| GET | `/reports/overview` | admin | Báo cáo cho Dashboard: `today_revenue`, `yesterday_revenue`, `week_revenue` (từ thứ Hai), `last_week_revenue`, `today_orders`, `today_members`; `revenue_by_day` (7 ngày), `revenue_by_week` (6 tuần), `revenue_by_month` (6 tháng) dạng `[{label, amount}]` cũ nhất trước; `top_foods` (tối đa 10 món bán nhiều nhất trong `top_foods_days` = 30 ngày) |
| GET | `/reports/revenue?from=YYYY-MM-DD&to=YYYY-MM-DD` | admin | Doanh thu từng ngày trong khoảng ngày tùy chỉnh (tính cả hai đầu, tối đa 31 ngày, `to` không quá hôm nay): `from`, `to`, `total`, `revenue_by_day` dạng `[{label: "dd/mm", amount}]`. Sai khoảng ngày trả 422 |

Mỗi phần tử trong `items` / `pre_order_items`: `{ "food_id": 1, "quantity": 2, "option_ids": [2, 7], "note": "..." }`.
**Giá luôn do server tính** từ database, client không cần (và không thể) gửi giá.

### Quy tắc nghiệp vụ cần biết

- **Một bàn chỉ có một đơn đang mở.** Gọi thêm món cho bàn đang có khách thì món được thêm vào đơn cũ (trả 200 thay vì 201). Nếu đơn đã "đang phục vụ", nó quay lại "đã đặt" để bếp làm tiếp.
- **Trạng thái đơn chỉ đi tiến:** `placed → preparing → serving → completed`. Hủy (`cancelled`) được khi đơn còn mở và chưa thanh toán.
- **Thanh toán** tạo hóa đơn, đặt đơn thành `completed` + `paid` và trả bàn về `empty`. Mỗi đơn chỉ thanh toán một lần.
- **Dùng điểm thưởng** (`points_used`) chỉ với đơn gắn khách thành viên (đơn khách tự đặt qua app). Khách phải đủ điểm và số điểm không vượt quá số tiền còn phải trả sau voucher; điểm bị trừ cùng lúc với việc tạo hóa đơn. Giảm giá trên hóa đơn = voucher + điểm. Điểm hiện chỉ được dùng, chưa tự cộng khi thanh toán.
- Trong thông tin đơn, `customer_points` cho thu ngân biết khách còn bao nhiêu điểm.
- **Giữ bàn (đặt bàn qua app 3 bước):** `POST /reservations` với `hold=true` giữ bàn 10 phút (`is_held=true`, `hold_expires_at`). Khách hoàn tất đặt món trước / thanh toán rồi gọi `confirm`; thoát giữa chừng thì gọi `PATCH .../cancel`. Quá hạn mà không xác nhận (kể cả khi app bị tắt) thì lượt đặt **tự hủy** và bàn được nhả; lượt hết hạn không còn chặn việc đặt bàn của người khác.
- **Đặt bàn** kiểm tra: đủ chỗ cho số khách, các bàn ghép cùng khu vực, không trùng giờ (±2 tiếng) với lượt đặt khác, thời gian phải ở tương lai.
- **Trạng thái bàn trong API:** bàn đang trống nhưng có lượt đặt bắt đầu trong khoảng từ 30 phút trước đến 60 phút sau thì được báo `reserved`.
- **Báo cáo:** doanh thu = tổng hóa đơn đã thanh toán theo giờ của quán (sau khuyến mãi); doanh thu từng món trong `top_foods` tính trước khuyến mãi. `today_orders` không tính đơn hủy; `today_members` chỉ đếm khách có tài khoản (đơn gọi tại bàn không gắn khách).
- **Khóa tài khoản** (trong admin) thu hồi token ngay, app bị đăng xuất.

## 7. Chạy bộ test tự động

```bat
php artisan test
```
Test chạy trên database trong bộ nhớ (cấu hình ở `phpunit.xml`), **không** ảnh hưởng database thật.

## 8. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| `401` dù đã đăng nhập | Thiếu `Bearer ` trước token, hoặc đã gọi `/logout` |
| `403` "Vai trò của bạn không được phép..." | Đang dùng token của vai trò khác, vd. nhân viên order gọi `/pay` |
| `422` khi tạo đơn | Đọc `message`: món hết hàng, chưa chọn bàn, option không thuộc món... |
| `Could not resolve host` / không kết nối được từ điện thoại | Chạy server với `--host=0.0.0.0`, dùng IP LAN, kiểm tra tường lửa |
| Ảnh món không hiện | Chạy `php artisan storage:link` một lần |
