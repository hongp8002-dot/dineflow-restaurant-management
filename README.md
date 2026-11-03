# DineFlow – Frontend UI (Flutter, Mock Data)

Khung giao diện (UI/UX) cho ứng dụng quản lý nhà hàng/quán cafe DineFlow.
**Giai đoạn này chỉ là frontend**: toàn bộ dữ liệu là mock data cố định
trong `lib/data/mock_data.dart`, chưa kết nối API/Laravel/PostgreSQL,
chưa có authentication thật.

## Cách chạy dự án

Thư mục này hiện chỉ chứa mã nguồn Dart (`lib/`) và `pubspec.yaml`.
Vì môi trường tạo ra project này không có sẵn Flutter SDK để chạy
`flutter create`, bạn cần tự sinh phần khung nền tảng (Android/iOS/Web...)
một lần trên máy của mình bằng các bước sau:

```bash
# 1. Giải nén / copy toàn bộ thư mục dineflow vào máy

# 2. Sinh các thư mục nền tảng (android, ios, web...) mà KHÔNG ghi đè lib/ và pubspec.yaml
flutter create .

# 3. Cài dependencies
flutter pub get

# 4. Chạy ứng dụng
flutter run
```

`flutter create .` chạy trong một thư mục đã có `pubspec.yaml`/`lib/` sẽ
chỉ bổ sung các thư mục nền tảng còn thiếu (android/ios/web/...), không
đụng vào code hiện có.

## Đăng nhập demo

Màn hình Login có một bộ chọn **"Đăng nhập với vai trò (demo UI)"**.
Vì chưa có backend nên ứng dụng chưa thể biết tài khoản thuộc vai trò
nào — bộ chọn này chỉ để tiện xem giao diện của cả 4 vai trò
(Khách hàng, Nhân viên Order, Thu ngân, Admin). Khi tích hợp API thật,
vai trò sẽ được lấy từ response đăng nhập và bộ chọn này sẽ được gỡ bỏ.

Nhập bất kỳ email/số điện thoại + mật khẩu (≥ 4 ký tự) để qua bước
validate rồi vào thẳng giao diện vai trò đã chọn.

## Cấu trúc thư mục

```text
lib/
├── main.dart                # Khởi tạo app, init locale vi_VN
├── app/
│   ├── app.dart              # MaterialApp, theme, route gốc
│   └── routes.dart           # Tên route + onGenerateRoute
├── models/                   # Các model Dart thuần (không phụ thuộc UI)
├── data/
│   ├── mock_data.dart         # Toàn bộ dữ liệu mẫu
│   └── cart_store.dart        # Danh sách món đã chọn / order đang tạo (ChangeNotifier, lưu trong RAM)
├── screens/
│   ├── auth/                  # Login, Register
│   ├── customer/               # 9 màn hình Khách hàng + shell bottom nav
│   ├── order_staff/            # 7 màn hình Nhân viên Order + shell
│   ├── cashier/                 # 7 màn hình Thu ngân + shell
│   └── admin/                   # 6 màn hình Admin + shell (rail/bottom nav)
├── widgets/                   # 13 widget dùng chung (xem "Reusable widgets")
├── theme/                     # app_colors.dart, app_theme.dart
└── utils/formatters.dart      # Định dạng tiền tệ, ngày giờ
```

## Trạng thái triển khai theo Phase

| Phase | Nội dung | Trạng thái |
|---|---|---|
| 1 | Project structure, theme, routes, mock data, models | ✅ Hoàn thành |
| 2 | Login/Register, Customer UI (9 màn hình) | ✅ Hoàn thành |
| 3 | Order Staff UI (7 màn hình) | ✅ Hoàn thành |
| 4 | Cashier UI (7 màn hình) | ✅ Hoàn thành |
| 5 | Admin UI (6 màn hình) | ✅ Hoàn thành |
| 6 | Navigation, kiểm tra route, UI consistency | ✅ Hoàn thành (xem "Giới hạn đã biết") |

## Reusable widgets (`lib/widgets`)

`AppButton`, `AppTextField`, `FoodCard`, `CategoryChip`, `TableCard`,
`OrderCard`, `InvoiceCard`, `StatCard`, `StatusBadge`, `AppSearchBar`,
`EmptyState`, `SectionHeader`, `MockBarChart` (biểu đồ cột tự vẽ bằng
`CustomPainter`, không dùng thư viện chart ngoài, phục vụ Dashboard/Báo
cáo doanh thu) và `app_animations.dart` (bộ hiệu ứng dùng chung).

## Bảng màu & chuyển động

Tông thương hiệu: **vàng - đen - trắng/kem** (theo ảnh tham khảo của nhóm).

| Vai trò | Hằng số | Mã màu | Dùng ở đâu |
|---|---|---|---|
| Vàng thương hiệu | `AppColors.primary` | `#F7C948` | Nền nút chính, chip đang chọn, badge, khối nhấn |
| Vàng đậm | `AppColors.primaryDark` | `#E3A812` | Gradient, viền khi focus, icon sao |
| Vàng nhạt / rất nhạt | `AppColors.primaryLight` / `primarySoft` | `#FFF4D4` / `#FDE9A9` | Nền pill, ô icon, khối thông tin |
| Đen | `AppColors.ink` | `#1A1714` | Chữ, khối nhấn tương phản (thẻ thành viên, nút phụ) |
| Nền / bề mặt | `background` / `surface` / `surfaceAlt` | `#FDFAF3` / `#FFFFFF` / `#FBF6EA` | Nền màn hình, card |

**Quy ước quan trọng**: màu vàng chỉ dùng làm **nền**. Chữ/icon nằm trên
nền vàng dùng `AppColors.textOnPrimary` (đen); chữ nhấn trên nền trắng
dùng `AppColors.textPrimary` (đen) chứ **không** dùng vàng, vì chữ vàng
trên nền trắng gần như không đọc được.

### Chế độ tối (Dark mode)

Người dùng chọn **Giao diện: Sáng / Tối / Theo hệ thống** ở trang tài khoản
(Khách hàng: Tài khoản → mục "Giao diện"; Nhân viên Order và Thu ngân: tab Cá
nhân). Mặc định là Sáng; lựa chọn chỉ lưu trong RAM như các dữ liệu mock khác
(tắt app mở lại sẽ về Sáng).

- Có hai bảng màu `AppPalette.light` / `AppPalette.dark` trong
  `lib/theme/app_colors.dart`. Tên màu giữ nguyên nghĩa ở cả hai chế độ, ví
  dụ `ink` luôn là "khối nhấn tương phản với nền" (nâu đen khi sáng, kem sáng
  khi tối) và `textOnDark` luôn là chữ nằm trên khối `ink`.
- `AppColors.xxx` giờ là **getter đọc bảng màu đang dùng, không còn là hằng
  số**: không đặt chúng trong biểu thức `const` (vd `const TextStyle(color:
  AppColors.textPrimary)` sẽ báo lỗi) và không dùng làm giá trị mặc định của
  tham số (để tham số `null` rồi lấy màu trong `build`).
- Chữ/icon trên nền vàng **phải** dùng `textOnPrimary` (chế độ sáng trùng màu
  với `textPrimary` nên dễ dùng nhầm, sang chế độ tối sẽ thành chữ kem trên
  nền vàng). Chữ vàng đặt trên khối `ink` dùng `primaryOnInk`.
- Mã QR thẻ thành viên luôn in đậm trên nền trắng ở cả hai chế độ để máy
  quét đọc được.
- `DineFlowApp` (`lib/app/app.dart`) lắng nghe `AppThemeSettings.mode` và độ
  sáng của hệ điều hành; khi đổi bảng màu thì yêu cầu dựng lại toàn bộ cây
  widget (giữ nguyên màn đang mở và dữ liệu đang nhập).

Bộ chuyển động nằm ở `lib/widgets/app_animations.dart`:

- `AppMotion`: thời lượng (`fast`/`normal`/`slow`), đường cong và hàm
  `stagger(index)` để các phần tử xuất hiện lần lượt.
- `FadeSlideIn` / `FadeSlideIn.staggered`: hiện dần + trượt lên, dùng cho
  item danh sách và các section của trang chủ.
- `PressScale`: thu nhỏ khi chạm, tạo phản hồi cho card/chip/nút tự vẽ.
- `AnimatedValueText`: đổi số (giá tiền, số lượng) có chuyển tiếp trượt.
- `CountUpText`: đếm tăng dần, dùng cho điểm thưởng.

Ngoài ra `AppTheme` cấu hình hiệu ứng chuyển trang mờ + trượt nhẹ cho toàn
app. Thanh điều hướng dưới cùng được tách thành widget dùng chung
`AppBottomNav` (tab đang chọn nằm trong "viên thuốc" vàng), hiện dùng cho cả
`CustomerShell` lẫn `OrderStaffShell`.

**Lưu ý khi thêm animation mới**: không dùng animation lặp vô hạn
(`controller.repeat()`) trên các màn hình chính, vì `pumpAndSettle()`
trong widget test sẽ không bao giờ kết thúc và test sẽ timeout.

## Quyết định thiết kế cần lưu ý

- **State management**: chỉ dùng `setState` + một `ChangeNotifier` đơn
  giản cho danh sách món (`CartStore`), theo đúng yêu cầu "không tạo state
  management phức tạp ở giai đoạn này".
- **Ảnh món ăn**: dùng Icon + màu nền thay vì ảnh mạng, để UI luôn hiển
  thị đúng kể cả khi không có internet (giai đoạn mock data).
- **QR thành viên**: vẽ giả lập bằng `CustomPainter`, không thêm thư
  viện `qr_flutter` vì chưa cần thiết ở giai đoạn UI-only.
- **Biểu đồ doanh thu**: tự vẽ bằng `CustomPainter`/`Container`, không
  thêm thư viện chart ngoài.

## Kiểm thử

```bash
flutter analyze
flutter test
```

- `test/booking_flow_test.dart`: đi hết luồng đặt bàn (đăng nhập → trang
  chủ → 3 bước đặt bàn → xác nhận → tab Lịch đặt → huỷ), và luồng chọn món ở
  Thực đơn → thanh món đã chọn → đặt bàn → món có sẵn ở bước Đặt món trước →
  hiện trên thẻ ở tab Lịch đặt.
- `test/customer_screens_smoke_test.dart`: dựng từng màn hình Khách hàng
  trên máy 360x800 và 320x640, báo đỏ ngay nếu có khối bị **tràn layout**;
  dựng thêm một lượt ở chế độ tối.
- `test/theme_mode_test.dart`: đổi Giao diện Sáng/Tối ở tab Tài khoản (cả app
  đổi màu, vẫn ở nguyên màn đang xem) và chế độ "Theo hệ thống".
  Nên chạy lại mỗi khi chỉnh style để không phải kiểm tra bằng mắt.
- `test/order_staff_screens_smoke_test.dart`: tương tự cho nhóm màn hình Nhân
  viên Order, kèm 2 test chức năng của màn tạo Order (khung "Order hiện tại"
  chỉ nở ra khi đã chọn món; bấm quay lại khi đang có món thì phải hỏi lại).
- `test/admin_screens_smoke_test.dart`: tương tự cho nhóm màn hình Admin,
  thêm cỡ tablet 800x1000 vì `AdminShell` đổi từ BottomNavigationBar sang
  NavigationRail khi bề ngang >= 640. Kèm 2 test chức năng: Dashboard phải
  có nút Đăng xuất, và khoá tài khoản phải ghi vào dữ liệu chung.

## Giao diện theo mockup của nhóm

Bốn màn được dựng lại theo bộ mockup đặt ở thư mục gốc dự án
(`Trang chủ@2x.png`, `Đăng nhập@1x.png`, `Đặt bàn@1x.png`, `Đơn gọi món@1x.png`):
Trang chủ, Đăng nhập và Đặt bàn. Màn "Đơn của bạn" (mockup `Đơn gọi món`) đã
được **bỏ** khi nhóm chốt lại luồng gọi món của khách - xem mục "Gọi món của
Khách hàng" bên dưới.

- Thanh điều hướng Khách hàng: **Trang chủ · Thực đơn · Đặt bàn · Lịch đặt ·
  Tài khoản**. Tab "Lịch đặt" thay cho tab "Đơn hàng" của mockup; lịch sử đơn
  đã ăn nằm trong Tài khoản → "Lịch sử đơn hàng".
- Màn con chuyển tab bằng `CustomerShell.goTo(context, CustomerTab.booking)`;
  mở thẳng một tab bằng `pushNamed(AppRoutes.customerHome, arguments: CustomerTab.bookings)`.
- Tông màu chữ/khối nhấn đổi sang **nâu đen ấm** `#3A2E25`, nền trắng, khối phụ
  màu kem `#F8F4EC`, nhãn nhỏ in hoa dùng `AppColors.accent`.

Các màn **chưa có mockup** được đồng bộ theo cùng ngôn ngữ thiết kế:

- Màn Khách hàng còn lại (Thực đơn, Tài khoản, Chi tiết món, Lịch đặt,
  Lịch sử đơn, Chi tiết đơn, Thẻ thành viên, Xác nhận đặt bàn) và màn Đăng ký:
  tiêu đề lớn trong trang qua widget dùng chung `AppPageHeader` (tự hiện nút
  quay lại khi màn được mở chồng), khối phụ nền kem phẳng, ảnh món sọc chéo.
- Admin: đồng bộ qua hệ thống dùng chung (AppBar tiêu đề lớn, không đổ
  bóng, chip/ô tìm kiếm/dòng cài đặt/ô thống kê theo kiểu mockup); bố cục
  từng màn giữ nguyên vì chưa có mockup. (Nhân viên Order và Thu ngân đã có
  mockup riêng - xem các mục dưới.)
- `AppColors.softShadow`/`goldShadow` để trống và `goldGradient`/`inkGradient`
  là màu phẳng (mockup không dùng bóng và gradient); muốn bật lại chỉ cần sửa
  trong `app_colors.dart`.

Những chỗ cố ý **khác mockup** (cần nhóm quyết định thêm):

| Mockup | Trong app | Lý do |
|---|---|---|
| Đặt bàn không có bước chọn bàn | Có khối "Chọn bàn" giữa Khu vực và Ghi chú | Giữ tính năng ghép bàn nhóm đã chốt |
| Khu vực "Trong nhà / Sân vườn / Phòng riêng" | Hiển thị khu vực thật trong dữ liệu (Tầng 1, Tầng 2) | Không tự đổi dữ liệu |
| Tab "Đơn hàng" + màn "Đơn của bạn" (chip "Bàn 21", nút gửi đơn tới bếp) | Tab "Lịch đặt" | Không quét QR tại bàn nên app không biết khách ngồi bàn nào; khách chỉ gọi món qua đặt món trước |
| Ô ảnh món sọc chéo trơn | Sọc chéo + icon món ở giữa | Chưa có ảnh thật, icon giúp nhận ra món |

## Giao diện Nhân viên Order theo mockup

8 màn được dựng lại theo bộ mockup ở thư mục gốc (`Sơ đồ bàn@1x.png`,
`Chọn bàn để Order@1x.png`, `Chi tiết bàn@1x.png`, `Order món@1x.png`,
`Chuyển bàn@1x.png`, `Gộp bàn@1x.png`, `Đơn đang phục vụ@1x.png`, `Cá nhân@1x.png`).

- **Dải tiêu đề vàng nhạt** (`AppHeaderBand`): trang tab có dòng phụ nhỏ phía
  trên tiêu đề ("10 bàn · 2 khu vực", "3 đơn đang mở"...); trang mở chồng có
  nút quay lại tròn trắng và dòng mô tả phía dưới. Thân trang nền kem, khối trắng.
- **Ô bàn** (`StaffTableTile` / `StaffTableGrid`): số bàn 2 chữ số lớn + sức
  chứa + trạng thái. Màu theo trạng thái gom ở `tableTileVisual()`:
  Trống = trắng, Đang phục vụ = nâu đen, Đặt trước = vàng. Bàn đang chọn
  (Chuyển/Gộp bàn) có viền nâu đen bao ngoài và dấu ✓.
- **Order món**: bỏ khung "Order hiện tại" riêng; số lượng chỉnh ngay trên
  dòng món (nút + → bộ − số +), tổng tiền và "Gửi Order" ở thanh dưới.
  Chạm vào dòng món vẫn tăng số lượng như trước.
- **Đơn đang phục vụ**: thẻ đơn dùng chung `OrderCard` - viên trạng thái
  "Đang phục vụ" nâu đen, "Đang chuẩn bị" vàng (áp dụng cả Lịch sử/Chi tiết
  đơn của Khách hàng cho thống nhất).
- **Cá nhân**: mục "Sơ đồ bàn"/"Đơn đang phục vụ" chuyển tab bằng
  `OrderStaffShell.goTo(context, StaffTab.serving)` thay vì mở thêm một
  khung điều hướng mới chồng lên.

Những chỗ **khác mockup**:

| Mockup | Trong app | Lý do |
|---|---|---|
| Order món không có ghi chú món | Món đã chọn có link "Thêm ghi chú" dưới giá | Giữ tính năng ghi chú cho bếp (vd "ít cay") |
| Chi tiết bàn không có giờ bắt đầu phục vụ | Bỏ dòng "Bắt đầu phục vụ lúc..." | Theo mockup; giờ tạo đơn vẫn hiện ở "Đơn #ORD1 · 18:07" |
| Nhãn "Phục vụ" cạnh tiêu đề Sơ đồ bàn | Nhãn tĩnh | Chưa có dữ liệu ca/trạng thái làm việc của nhân viên |

Cần nhóm chốt về nghiệp vụ (giao diện chưa tự quyết):

- Gộp bàn: mockup cho chọn mọi bàn (cả trống, đặt trước) - app đang làm
  theo mockup; nếu chỉ cho gộp bàn đang phục vụ thì backend/nhóm cần chốt.
- Chuyển bàn: chỉ liệt kê bàn **trống** (giữ như cũ, khớp mockup).
- "Yêu cầu thanh toán" chỉ bấm được với bàn đang phục vụ (giữ như cũ).
- Các màn Khách hàng (Đặt bàn) và Admin (Quản lý bàn) vẫn dùng màu trạng
  thái bàn cũ xanh/đỏ/cam; có thể đổi sang bộ màu mới nếu nhóm muốn thống nhất.

## Giao diện Thu ngân theo mockup

7 màn được dựng lại theo mockup ở thư mục gốc (`Tổng quan ca làm@1x.png`,
`Chờ thanh toán@1x.png`, `Thanh toán@1x.png`, `Hóa đơn@1x.png`,
`Lịch sử thanh toán@1x.png`, `Ca làm việc@1x.png`, `Cá nhân@1x (1).png`),
cùng phong cách với Nhân viên Order: dải tiêu đề vàng nhạt `AppHeaderBand`,
thân trang nền kem, khối trắng.

- **Tổng quan ca làm**: thẻ ca đang mở + nút "Chi tiết", khối doanh thu hôm
  nay, 3 ô đếm đơn, "Truy cập nhanh". Nút "Chi tiết" và các ô truy cập nhanh
  chuyển tab bằng `CashierShell.goTo(context, CashierTab.shift)` thay vì mở
  thêm màn chồng lên (tab Cá nhân cũng vậy).
- **Chờ thanh toán**: "Đang xử lý" = viên nâu đen, "Chưa thanh toán" = viên
  trắng viền mảnh.
- **Thanh toán**: voucher dạng viên (đang chọn nền nâu đen), thanh trượt điểm
  thưởng, khối tổng tiền có đường kẻ đứt, 3 ô phương thức nằm ngang.
- **Hóa đơn**: tờ hoá đơn trắng, logo vàng, các phần ngăn bằng kẻ đứt.
- **Lịch sử thanh toán**: ô icon theo phương thức (tiền mặt / QR / thẻ).
- **Ca làm việc**: thanh tỉ lệ doanh thu theo phương thức (chạy dần khi mở
  màn), nút "Đóng ca" ghim dưới.
- Widget dùng chung mới: `OrderItemsCard` (khung món, dùng cả ở Chi tiết bàn),
  `AccountIdentityCard` (thẻ tài khoản ở tab Cá nhân của 2 vai trò nhân viên),
  `DashedDivider` (kẻ đứt), `StatusBadge(borderColor:)` (viên có viền).

Những chỗ **khác mockup** (do dữ liệu mẫu khác số liệu minh hoạ trong ảnh):

| Mockup | Trong app | Lý do |
|---|---|---|
| Thu ngân "Ngọc Trâm" | Tên thu ngân trong dữ liệu mẫu | Không tự đổi dữ liệu |
| "Ca chiều · Bắt đầu lúc 14:00" | "Ca sáng · 07:00" | Chưa có dữ liệu ca làm; tạm đặt ở `CurrentShiftInfo` (shift_screen.dart) để 2 màn hiển thị giống nhau |
| Mã hoá đơn "#INV-005" | `#` + mã trong dữ liệu (vd `#INV1`) | Định dạng mã do backend quy định |
| Doanh thu hôm nay = tổng thu ca | Hai số khác nhau | `MockData.todayRevenue` và tổng các hoá đơn mẫu không khớp nhau - backend cần trả số liệu thống nhất |

Cần backend/nhóm chốt: thanh trượt điểm thưởng vẫn cho kéo tới bằng tổng
tiền đơn (chưa giới hạn theo số điểm khách đang có).

## Luồng đặt bàn qua app (Khách hàng)

**Đặt bàn → Đặt món trước (có thể bỏ qua) → Thanh toán → Thành công.**

- Xác nhận ở màn Đặt bàn là **giữ bàn** và bắt đầu đếm **10 phút**
  (`BookingCheckout.holdDuration`). Các màn sau có thanh 3 bước và đồng hồ đếm
  ngược; còn dưới 2 phút thì dải thông báo chuyển màu đỏ.
- Màn gọi món trong luồng này có tiêu đề **"Đặt món trước"**
  (`pre_order_screen.dart`). Món khách đã chọn ở Thực đơn / Trang chủ có sẵn ở
  đây (hai nơi dùng chung `AppCart.customer`).
- Không đặt món thì bước Thanh toán chỉ là "Xác nhận giữ bàn"; có món thì chọn
  phương thức (Ví/QR, Thẻ, Tiền mặt tại quán) và thanh toán.
- **Quá 10 phút** chưa xong cả 3 bước → lượt đặt bàn tự huỷ, báo khách và quay
  về màn Đặt bàn. **Thoát giữa chừng** (nút quay lại) → hỏi lại, đồng ý thì huỷ
  lượt đặt bàn để nhả bàn. Hai trường hợp này vẫn giữ các món đã chọn để khách
  đặt lại không phải chọn từ đầu.
- Thanh toán xong: món được lưu vào lượt đặt bàn (`Reservation.preOrderItems`,
  `preOrderPayment`) và danh sách món đã chọn được làm trống.

Việc cần **backend** đảm nhận (app hiện chỉ mô phỏng):
- Giữ bàn và tự huỷ khi hết hạn phải chạy **phía server** - đồng hồ trên app
  sẽ không chạy nếu khách tắt app giữa chừng.
- Lưu danh sách món đặt trước gắn với lượt đặt bàn (app đang lưu vào
  `MockData.reservations` qua `MockData.savePreOrder`).
- Xử lý thanh toán thật và quy định đặt cọc (nếu có).

## Gọi món của Khách hàng

Nhóm **không làm quét QR tại bàn**, nên app không biết khách đang ngồi bàn nào.
Vì vậy:

- **Gọi món tại quán** do **Nhân viên Order** nhập (luồng Tạo order có sẵn).
- **App khách chỉ gọi món theo một cách: đặt món trước khi đặt bàn.**
- Nút **+** ở Thực đơn / Trang chủ và nút **"Chọn món"** ở Chi tiết món chỉ đưa
  món vào danh sách "món đã chọn" (`AppCart.customer`), không gửi đi đâu.
- Khi có món, **thanh "món đã chọn"** (`PickedFoodsBar`) hiện ngay trên thanh
  điều hướng ở Trang chủ và Thực đơn: chạm bên trái để xem/sửa món (bảng
  "Món đã chọn"), nút **"Đặt bàn để gọi"** mở tab Đặt bàn. Tới bước "Đặt món
  trước" các món đã có sẵn.
- **Tab "Lịch đặt"** (`MyBookingsScreen`): lượt Sắp tới / Lịch sử, mỗi thẻ có
  khối món đặt trước (món, tổng tiền, "Đã thanh toán" hoặc "Trả tại quán").
  Màn tự cập nhật khi đặt/huỷ bàn nhờ `MockData.reservationsVersion`.
- **Món đặt trước được chốt khi thanh toán.** Muốn gọi thêm thì gọi nhân viên
  khi đến quán (thẻ đặt bàn có ghi rõ).

Cần nhóm chốt thêm: đơn mẫu `ord4`–`ord6` (người tạo "Đặt qua app", không có
bàn) trong Lịch sử đơn hàng không còn khớp luồng mới - nên gắn bàn hoặc đổi
thành đơn do nhân viên nhập.

## Quy tắc đặt bàn & ghép bàn

Nhà hàng hiện không có bàn nào quá 8 chỗ, nên nhóm khách đông hơn sức chứa
một bàn sẽ **ghép nhiều bàn** - đúng ý tưởng ghép bàn trong đề tài:

- Ở bước "Chọn bàn", khách bấm chọn **nhiều bàn**; mỗi bàn được chọn hiện số
  thứ tự ghép (1, 2, 3...) và thanh tổng kết cho biết đã đủ bao nhiêu chỗ.
- Nút "Tiếp tục" **bị chặn** cho tới khi tổng số chỗ của các bàn đã chọn
  `>=` số khách, kèm thông báo còn thiếu bao nhiêu chỗ.
- Chỉ ghép được các bàn **trong cùng một khu vực**; đổi khu vực sẽ bỏ chọn hết.
- Bộ đếm số khách giới hạn theo sức chứa thật (`MockData.maxPartySize` = tổng
  số chỗ trống của khu vực nhiều chỗ nhất), thay vì con số 40 cố định như
  trước. Vượt mức đó thì app hướng dẫn khách gọi điện cho nhà hàng.
- `Reservation` vì vậy lưu `tableIds` / `tableNumbers` dạng danh sách;
  `reservation.tableNumber` trả về chuỗi hiển thị dạng `Bàn 1 + Bàn 4`, còn
  `reservation.capacity` là **tổng** số chỗ của các bàn đã ghép.

## Giới hạn đã biết

- Dự án đã chạy `flutter analyze` (0 error, 0 warning) và `flutter test`
  (toàn bộ test xanh) trên Flutter 3.48 beta. Các cảnh báo còn lại chỉ ở
  mức `info` (gợi ý `const`, vài API deprecated của Flutter mới).
- Các thao tác thêm/sửa/xóa ở Admin (tài khoản, món ăn, khuyến mãi, bàn)
  hiện chỉ hiển thị `SnackBar` xác nhận (demo UI), chưa cập nhật lại
  danh sách vì chưa có backend lưu trữ thật.
