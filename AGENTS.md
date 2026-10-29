# AGENTS.md — Delicia (Flutter Food Delivery App)

> Tài liệu này tóm tắt **context hiện tại** của project để agent/AI (hoặc người mới) làm việc ngay mà không cần đọc toàn bộ codebase.
>
> **Phân biệt với `tasks/agent.md`**: `tasks/agent.md` là *spec gốc* (222 KB, mô tả toàn bộ app Frave để tái tạo) — tham khảo khi cần chi tiết UI/kiến trúc lịch sử. File này là **bản đồ trạng thái hiện tại**.
>
> **Phân biệt với `README.md`**: README là hướng dẫn cho người mới chạy app. File này là bản đồ kỹ thuật cho người sửa code.

---

## 1. Tổng quan

| Mục | Giá trị |
|---|---|
| Tên package | `delicia` |
| Version | `1.0.0+1` |
| Flutter | **3.47.0** (stable) · Dart **3.13.0** |
| Nền tảng | Android (chính) · iOS/Web (shell có sẵn, chưa test) |
| Loại app | Giao đồ ăn đa vai trò: **Client** (đặt món) · **Admin** (nhà hàng) · **Delivery** (tài xế) |
| Backend | Firebase Auth + Realtime Database + Storage. **Không có server riêng** |
| Bản đồ | OpenStreetMap qua `flutter_map` — **không cần API key, không billing** |
| Định tuyến | OSRM public demo (`router.project-osrm.org`) — không cần API key |
| Thanh toán | `CASH` (mặc định) + **payOS** (gateway thật, đã triển khai nhưng **tắt mặc định**) |
| Repo | `https://github.com/NhatToann/delicia.git` |
| Branch hiện tại | `nhattoan/feature/port-client-ui-from-frave` |

### Design source

Toàn bộ UI được **port từ Figma** theo từng node, không phải dựng tự do:
- Figma file: `tVh0aA6EL18IotmAMXwO3p` — *"Food Delivery App UI Kit"*
- Bản ảnh local: `assets/Food Delivery App UI Kit Food App Design Food Mobile App Delivery UI (Community)/`
- Font chính: **League Spartan** (variable font, node `47:23`)
- Frame chuẩn: **393 × 852** (iPhone 14 Pro)

---

## 2. Stack & thư viện

```yaml
# State
bloc: ^8.1.4            flutter_bloc: ^8.1.6
# Firebase
firebase_core: ^3.6.0   firebase_auth: ^5.3.1
firebase_database: ^11.1.2   firebase_storage: ^12.3.4
# Routing
go_router: ^14.6.2
# Maps + Realtime
flutter_map: ^7.0.2     flutter_map_animations: ^0.8.0
latlong2: ^0.9.1        geolocator: ^12.0.0
geocoding: ^5.0.0       permission_handler: ^11.3.1
# Payment
crypto: ^3.0.7          http: ^1.2.2
# UI
google_fonts: ^4.0.4    flutter_svg: ^2.0.5
font_awesome_flutter: ^10.4.0   shimmer: ^2.0.0
intl: ^0.18.1           cached_network_image: ^3.4.1
# Storage
flutter_secure_storage: ^9.2.2    shared_preferences: ^2.3.2
# Dev
bloc_test: ^9.1.7       mocktail: ^1.0.4    flutter_lints: ^6.0.0
```

### Pin cứng — đừng nâng phiên bản tùy tiện

| Package | Pin | Lý do |
|---|---|---|
| `flutter_map_animations` | `0.8.x` | `0.9+` yêu cầu `flutter_map >= 8.0.0`, project đang ở `7.x` |
| `sliding_up_panel` | **không dùng** | Bị kẹt ở Dart SDK constraint `<3.0.0`. Bottom sheet Grab-style dùng `DraggableScrollableSheet` của Flutter |
| `google_maps_flutter` | **không dùng** | Thay bằng OSM để không cần API key/billing |
| `firebase_messaging` | **chưa thêm** | Cố ý defer tới UC-12 để build auth-flow sạch |

---

## 3. Cấu trúc thư mục

```
delicia/
├── lib/
│   ├── main.dart                    # MultiBlocProvider + MaterialApp.router
│   ├── router/app_router.dart       # GoRouter — 18 routes
│   ├── data/
│   │   ├── env/environment.dart     # Config tập trung + CartPricing
│   │   └── services/route_service.dart  # OSRM routing + polyline decode
│   ├── domain/
│   │   ├── bloc/                    # 7 bloc đang hoạt động
│   │   │   ├── auth/  cart/  orders/  payment/  products/
│   │   │   └── map_client/  map_delivery/
│   │   ├── models/                  # 13 model thuần Dart
│   │   └── services/                # 7 service (abstract + Firebase impl)
│   │   └── utils/                   # text_normalizer (bỏ dấu tiếng Việt)
│   └── presentation/
│       ├── components/              # BtnFrave, TextCustom, FormFieldFrave, ShimmerFrave, auth_*
│       │   └── map/                 # route_polyline_layer, driver_card, eta_bar, order_timeline, grab_bottom_sheet
│       ├── helpers/                 # modal_loading, modal_success, error_message, image_resolver, category_assets
│       ├── screens/                 # intro/ login/ home/ (splash, welcome, auth, select-role)
│       ├── client/                  # home/ search/ product_detail/ cart/ payment/ orders/ address/ map/
│       ├── delivery/map/            # map_delivery_screen
│       ├── themes/                  # colors_frave.dart, type_frave.dart
│       └── animations/
├── test/                            # 33 file — bloc test + widget test + geometry test
├── docs/plans/                      # 2 design spec (cart-checkout, payment-screen)
├── tasks/                           # 12 use-case spec + agent.md gốc  [GITIGNORED]
├── scripts/                         # setup-branches.sh + seed_catalog.json + catalog_reference.json (tracked)
└── assets/
    ├── fonts/LeagueSpartan.ttf       # variable font duy nhất
    ├── logos/ icons/ categories/ products/ map/     # TRACKED
    └── figma_home/ figma_cart/ figma_payment/ figma_raw/  # CHƯA TRACK
```

**Quy ước layer:** `data` (hạ tầng) → `domain` (logic, bloc, service) → `presentation` (UI). `presentation` **không** được gọi Firebase trực tiếp — luôn qua bloc.

---

## 4. Data model — cây Realtime Database

```
delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app
└── delicia/                        ← Environment.dbRoot
    ├── categories/{categoryId}
    ├── products/{productId}
    │   └── images/{imageId}
    └── orders/{orderId}
        ├── clientId, addressId, street, reference
        ├── latitude, longitude
        ├── paymentMethod, amount, status
        ├── products[]               ← snapshot array
        └── shipperLocation          ← realtime vị trí tài xế
            └── latitude, longitude, timestamp

users/{uid}                          ← KHÔNG nằm dưới dbRoot
├── email, firstName, lastName, phone, image
└── rolId                            1=Admin, 2=Client, 3=Delivery
```

### Trạng thái đơn hàng (`OrderRecord.status`)

| Hằng số | Giá trị | Ý nghĩa |
|---|---|---|
| `statusPaidOut` | `PAID OUT` | Client đã thanh toán, chờ nhà hàng |
| `statusDispatched` | `DISPATCHED` | Đã gán tài xế |
| `statusOnWay` | `ON WAY` | Tài xế đang giao |
| `statusDelivered` | `DELIVERED` | Hoàn tất |
| `statusCancelled` | `CANCELLED` | Client huỷ (chỉ khi còn `PAID OUT`) |

Logic liên quan nằm trong `OrderRecord`:
- `canTrackDelivery` → chỉ `DISPATCHED` / `ON WAY` mới mở được map live
- `canCancel` → chỉ `PAID OUT`

---

## 5. BLoC catalog

| Bloc | Phụ trách | Sự kiện chính |
|---|---|---|
| `AuthBloc` | UC-01: login/register/forgot/checkSession/logout | `LoginEvent`, `RegisterEvent`, `CheckLoginEvent`, `ForgotPasswordEvent`, `LogOutEvent` |
| `ProductsBloc` | UC-02: catalog, search, home feed 3 rail | `OnGetHomeFeedEvent`, `OnSearchProductEvent` (debounce 300ms), `OnSelectCategoryEvent`, `OnToggleFavoriteEvent` |
| `CartBloc` | UC-04: giỏ hàng in-memory | `OnAdd/Delete/Increase/Decrease/ClearProductToCartEvent` + 3 event số lượng của sản phẩm đang chọn |
| `OrdersBloc` | UC-04/05: tạo đơn + danh sách đơn realtime | `OnAddNewOrdersEvent`, `OnLoadMyOrdersEvent`, `OnCancelOrderEvent` (optimistic + rollback), `OnChangeOrderFilterEvent` |
| `PaymentBloc` | UC-04: online gateway (payOS) | `OnStartPayOsPayment`, `OnVerifyPayOsPayment`, `OnResetPaymentEvent` |
| `MapClientBloc` | UC-03: map phía khách | `OnInitSocketEvent`, `OnUpdateDeliveryPositionEvent`, `OnRouteLoadedEvent` |
| `MapDeliveryBloc` | UC-03: map phía tài xế | `OnUpdateCurrentLocationEvent`, `OnConnectSocketEvent` |

### Pattern BLoC bắt buộc

```dart
// 1 file bloc + 2 file part, KHÔNG dùng Freezed
part 'xxx_event.dart';
part 'xxx_state.dart';

// State: base class + subclass, dùng copyWith để merge
// Service: abstract interface + Firebase impl, BLoC chỉ nhận interface
class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc({required OrdersService ordersService}) : ... { }
}
```

> **Quy tắc vàng:** BLoC **không** giữ `Emitter` lâu. Khi có stream bên ngoài (Firebase listener), listener phải `add()` một internal event thay vì `emit()` trực tiếp — vì `Emitter` đã đóng khi handler kết thúc. Xem `_OnMyOrdersUpdatedEvent` trong `orders_bloc.dart`.

---

## 6. Services

| File | Interface | Impl | Ghi chú |
|---|---|---|---|
| `auth_service.dart` | — | `AuthService` | Firebase Auth + RTDB. Tự upsert profile nếu thiếu. Map lỗi Firebase → message tiếng Anh |
| `catalog_service.dart` | `CategoryService`, `ProductsService` | — | Interface thuần, test dùng fake |
| `products_service.dart` | — | `FirebaseCategoryService`, `FirebaseProductsService` | `delicia/categories`, `delicia/products` |
| `orders_service.dart` | `OrdersService` | — | Interface thuần |
| `firebase_orders_service.dart` | — | `FirebaseOrdersService` | `delicia/orders`, query `orderByChild('clientId').equalTo(...)` |
| `realtime_service.dart` | — | `RealtimeService` | Publish/subscribe `orders/{id}/shipperLocation` |
| `payment_gateway.dart` | `PaymentGateway` | `PayOsGateway` | HMAC-SHA256 signature, convert VND |
| `data/services/route_service.dart` | — | `RouteService` | OSRM, memoize theo cặp điểm làm tròn 1e-5 |

### `Environment` — config tập trung

```dart
Environment.firebaseDatabaseUrl  // asia-southeast1 — sai region là app chết
Environment.dbRoot = 'delicia'
Environment.tileServerUrl         // OSM tiles
Environment.defaultDeliveryFee = 2.5
Environment.estimatedDeliveryMinutes = 25
Environment.payosClientId / ApiKey / ChecksumKey   // RỖNG → payOS bị ẩn
Environment.payosVndRate = 25000
```

`CartPricing` (cùng file) là **nguồn duy nhất** cho mọi con số tiền: `deliveryFee`, `taxRate = 0.05`, `taxOf()`, `totalOf()`. **Không hardcode giá** — Figma chỉ có giá mẫu (`$40.00`, `$5.00`) để demo layout.

---

## 7. Routing (18 routes)

| Path | Screen | UC |
|---|---|---|
| `/splash` | `LaunchFirstScreen` | UC-01 |
| `/intro` | `LaunchWelcomeScreen` | UC-01 |
| `/login` | `LoginScreen` | UC-01 |
| `/register` | `RegisterClientScreen` | UC-01 |
| `/forgot-password` | `ForgotPasswordScreen` | UC-01 |
| `/check-email` | `CheckEmailScreen` | UC-01 |
| `/select-role` | `SelectRoleScreen` | UC-01 |
| `/client/home` | `ClientHomeScreen` | UC-02 |
| `/client/search-category` | `SearchForCategoryScreen` | UC-02 |
| `/client/details-product/:id` | `ProductDetailScreen` | UC-02 |
| `/client/cart` | `CartScreen` (drawer) | UC-04 |
| `/client/payment` | `PaymentScreen` | UC-04 |
| `/client/orders` | `ClientOrdersScreen` | UC-05 |
| `/client/select-address` | `SelectAddressScreen` | UC-04/06 |
| `/client/map` | `MapClientScreen` | UC-03 |
| `/delivery/map/:orderId` | `MapDeliveryScreen` | UC-03 |
| `/admin/home` · `/delivery/home` | `HomePlaceholder` | **placeholder** |

### Luồng chính

```
Splash → (session?) → Intro → Login → Select Role
                                    ├─ rolId 2 → /client/home
                                    ├─ rolId 1 → /admin/home   (placeholder)
                                    └─ rolId 3 → /delivery/home (placeholder)

Client: Home → Product Detail → Cart (drawer) → Payment → Order confirmed → /client/orders
                                                                    └─ → /client/map (live track)
```

> `/client/checkout` **đã bị xoá** — `PaymentScreen` (Figma 4.3-D) là superset của nó (địa chỉ + summary + phương thức + ETA + Pay Now).

---

## 8. Design system

### Màu (`presentation/themes/colors_frave.dart`)

| Token | Hex | Dùng ở đâu |
|---|---|---|
| `launchBg` / `welcomeAccent` | `#F5CB58` | Launch First, band header, pill |
| `welcomeBg` / `navOrange` | `#E95322` | Launch Welcome, bottom nav, giá chip |
| `primaryColor` | `#D74E1E` | CTA, appbar, accent |
| `primaryBright` | `#FF642F` | accent trên nền sáng |
| `ink` | `#391713` | Heading, label (Figma "Font") |
| `onOrange` / `pageBg` | `#F8F8F8` | Text trên nền cam (Figma "Font 2") |
| `pillYellow` | `#F3E9B5` | Card địa chỉ, pill phương thức |
| `orangeSoft` | `#FFDECF` | Chip filter inactive, nút phụ |
| `dividerOrange` | `#FFD8C7` | Divider giữa các section |
| `secondaryColor` | `#2EC4B6` | Xanh nhấn |
| `tertiaryColor` | `#4A6FA5` | Xanh dương nhấn |

Palette auth (`authBg`, `authInk`, `authAccent`…) là bản **-10% dịu** của palette gốc để form dễ đọc.

### Chữ (`type_frave.dart`)

- Family duy nhất: **League Spartan** (`FraveText.family`)
- API: `FraveText.light/regular/medium/semiBold/bold(size, {color, height, letterSpacing})`
- Mặc định màu chữ: `ColorsFrave.ink`
- `height` mặc định `1.1` — đây là quyết định thiết kế, đừng đổi

### Bo góc (`RadiusFrave`)

`button = 26` · `field = 18` (pill input) · `card = 20` · `sheet = 28`

### Component có sẵn

`BtnFrave` · `TextCustom` · `FormFieldFrave` · `ShimmerFrave` · `AuthTextField` · `auth_widgets.dart` · `ImageResolver` (asset ↔ URL) · `modal_loading` · `modal_success` · `error_message`

---

## 9. Trạng thái triển khai theo use-case

| UC | Nội dung | Trạng thái |
|---|---|---|
| **UC-01** | Auth flow (splash → intro → login → register → forgot → role) | ✅ Xong |
| **UC-02** | Client Home + Browse + Search + Product Detail | ✅ Xong |
| **UC-03** | Realtime map (client + delivery) + OSRM route | ✅ Xong |
| **UC-04** | Cart → Payment → Order confirmed + Address picker | ✅ Xong |
| **UC-05** | Client Orders (list, filter chips, cancel) | ✅ Xong (preview) |
| **UC-06** | Profile / Edit profile / Change password / Address CRUD | 🔶 Mới có `SelectAddressScreen` + profile drawer. Thiếu: list address, edit profile, đổi mật khẩu |
| **UC-07** | Admin Dashboard | ⬜ Placeholder |
| **UC-08** | Admin CRUD category/product | ⬜ Placeholder (service đã có) |
| **UC-09** | Admin Orders 4-tab + delivery men | ⬜ Placeholder |
| **UC-10** | Delivery Home + 3 list | ⬜ Placeholder |
| **UC-11** | Delivery Detail + state machine | 🔶 Map delivery đã có, state machine chưa |
| **UC-12** | Polish + FCM + deploy | ⬜ Chưa bắt đầu. Không có CI (`.github/` chưa tồn tại) |

---

## 10. Workflow làm việc

### Branch

```
main
 ├── feat/uc-01-auth  … feat/uc-12-polish-deploy   (12 branch, đã tạo sẵn)
 └── feat/<feature-name>
```

- Mỗi use-case = 1 branch = 1 PR về `main`
- **Không push thẳng vào `main`**
- File chung (`main.dart`, `app_router.dart`, `pubspec.yaml`, `AndroidManifest.xml`, `environment.dart`) → PR riêng, Leader merge

### Commit message (Conventional Commits)

```
feat(uc-04): add PaymentBloc + PaymentScreen
fix(client): remove bottom overflow on product grid
docs(readme): add team + branches table
refactor(auth): extract error mapper
test(cart): add 3 tests for quantity stepper
```

### Trước khi push

```bash
flutter pub get
flutter analyze     # 0 error (info-level thì được)
flutter test        # 196 pass / 2 fail hiện tại — xem §12
flutter build apk --debug
```

### Không được push

`google-services.json` · `GoogleService-Info.plist` · `*.jks` / `*.keystore` · `tasks/` · `docs/internal/` · `build/` · `.dart_tool/` · `android/.gradle/`

---

## 11. Build & chạy

```bash
flutter pub get
flutter run -d <device-id>

flutter build apk --debug
flutter build appbundle --release     # cần keystore (UC-12)
```

**Bắt buộc trước khi chạy:** copy `android/app/google-services.json` từ Firebase Console (file này bị gitignore).

### Test

```bash
flutter test                              # toàn bộ
flutter test test/cart_bloc_test.dart     # 1 file
flutter test --coverage
```

| Loại test | Vị trí | Mục đích |
|---|---|---|
| Bloc test | `test/*_bloc_test.dart` | Logic bloc, dùng `bloc_test` + `mocktail` |
| Geometry test | `test/payment_geometry_test.dart`, `orders_geometry_test.dart` | Assert toạ độ render khớp node Figma |
| Widget test | `test/cart_panel_test.dart`, `orders_screen_test.dart`, `*_overflow_test.dart` | Render + overflow ở nhiều kích thước màn hình |
| Golden | `test/home_golden_test.dart` | Ảnh mẫu |
| Service test | `test/payment_gateway_test.dart`, `route_service_test.dart`, `realtime_service_test.dart` | Signature, polyline decode, listener |

---

## 12. Trạng thái build hiện tại (đo ngày 2026-10-26)

### `flutter analyze`

```
48 issues found — 0 error, 0 warning, 48 info
```

Toàn bộ là info-level, tập trung ở 2 chỗ:
- `lib/router/app_router.dart` — `unnecessary_underscores` (`(_, __)` → `(_, _)`)
- `test/helpers/load_fonts.dart` — `unnecessary_import` (`dart:typed_data`)

> 2026-10-26: giảm từ 62 → 49 sau khi xoá `tool/font_metrics.dart` (3 info) và dọn các probe còn lại.

### `flutter test`

```
346 pass / 0 fail
```

> 2026-10-26: 2 fail cũ (`home_golden_test.dart` + `home_positions_test.dart`, `0.24%, 787px diff`) đã **được sửa gốc**: greeting theo buổi trong header giờ lấy giờ từ **clock tiêm vào** (`ClientHomeScreen.clock`), nên ảnh golden không còn phụ thuộc giờ hệ thống. Xem §16.3.

| Test | Bảo vội cái gì |
|---|---|
| `test/catalog_vi_test.dart` | Catalogue tiếng Việt: search khớp cả VI/EN, artwork key theo `categoryId`, dòng legacy (tên EN) vẫn resolve đúng |
| `test/home_greeting_test.dart` | Greeting đúng bucket (sáng/trưa/tối) theo clock tiêm vào; không phụ thuộc đồng hồ thật |
> **Mâu thuẫn spec đã được giải quyết**: trước đây `test/cart_bloc_test.dart` và `test/cart_panel_test.dart` kỳ vọng qty 1 không giảm, còn code xoá dòng khi qty về 0. Cả hai giờ đều theo hướng **xoá dòng khi qty về 0**. Xem `tasks/use-case-04-cart-checkout.md`.

---

## 13. Gotchas — đọc trước khi sửa code

### Về Firebase

1. **Region sai → app chết ngay.** `Environment.firebaseDatabaseUrl` phải là `asia-southeast1`. Lỗi `Database lives in a different region`.
2. **`users/` KHÔNG nằm dưới `delicia/`.** Khác với `orders/`, `products/`, `categories/`.
3. **`google-services.json` bị gitignore.** Clone mới → màn hình đen. Phải copy từ Firebase Console.
4. **`_upsertMinimalProfile`** tự tạo profile nếu user thiếu node trong RTDB — cố ý để auth flow chống chịu partial write.
5. **⚠️ REST `PATCH` KHÔNG merge sâu — nó XOÁ field.** `PATCH /delicia/products` với body `{"p01": {"nameProduct": "X"}}` sẽ **thay thế toàn bộ** document `p01` bằng `{"nameProduct": "X"}`; mọi field khác (`price`, `rating`, `picture`, `status`…) bị **xoá mất**. Đây chính là nguyên nhân mọi giá hiện `0 ₫` tháng 10/2026. **Luôn dùng `PUT` với document đầy đủ** (đọc row sống → merge → PUT). Catalogue chuẩn: `scripts/catalog_reference.json`.

### Về Flutter / package

5. **GoRouter không `Navigator.popUntil`.** Muốn quay về `/intro` sau logout phải dùng `context.go('/intro')`. `Navigator.popUntil` sẽ không pop được route do GoRouter quản lý.
6. **`flutter_map_animations` phải ở `0.8.x`** — nâng lên `0.9+` là vỡ (yêu cầu `flutter_map >= 8`).
7. **Không thêm `sliding_up_panel`** — kẹt Dart 2 constraint. Dùng `DraggableScrollableSheet`.
8. **`http` vẫn còn dùng** cho OSRM + payOS (không phải REST backend).
9. **`ShimmerFrave` + `ImageResolver`** — ảnh catalog là **local asset** (`products/burger.png` → `assets/products/burger.png`), không phải URL. `ImageResolver` tự map; URL `http(s)` vẫn hỗ trợ qua `Image.network`.

### Về UI port từ Figma

10. **Payment screen dùng `Stack` + toạ độ tuyệt đối** (`PaymentGeometry`), không phải `Column`. Figma pin từng phần tử vào một `y` cụ thể trên frame 393×852 — layout flow sẽ vỡ khi số item trong giỏ thay đổi.
11. **Cart là drawer overlay** (`CartOverlay.show`), không phải route full-screen — theo Figma 4.3-A/B. Tái dùng pattern drawer của `ProfileMenuOverlay`.
12. **Sửa overflow = dùng `Flexible`/`Expanded` + `ClipRect`**, không dùng `MediaQuery` scale cứng. Có nhiều test `_overflow_test.dart` bảo vệ các màn hình này.
13. **Font phải load trong test** qua `test/helpers/load_fonts.dart`, nếu không text sẽ đo sai → geometry test fail.

### Về git & tài liệu

14. **`tasks/` bị gitignore.** Chỉ có trên máy local. `tasks/agent.md` (spec gốc) + `tasks/use-case-01..12-*.md`.
15. **Không có CI.** `README.md` nói có `.github/workflows/ci.yml` — **thực tế thư mục `.github/` không tồn tại**. Phải chạy `flutter analyze` + `flutter test` thủ công.
16. **`assets/figma_home/`, `assets/figma_cart/`, `assets/figma_payment/`, `assets/fonts/` chưa được track** trong git (chỉ `categories/ icons/ logos/ map/ products/` được track). Clone mới sẽ thiếu ảnh và font → text fallback, layout lệch.

### Về payment

17. **Checksum key của payOS KHÔNG được ship trong app.** `Environment.payosChecksumKey` để trống mặc định → phương thức PAYOS **bị ẩn khỏi danh sách**. Bật lên bằng cách điền credential, hoặc (đúng hơn) trỏ `payosApiBase` về backend nhỏ giữ key.
18. **payOS chỉ nhận VND nguyên** → `PayOsGateway.toVnd()` nhân với `payosVndRate = 25000`.
19. **Cash không đi qua `PaymentBloc`.** Cash settle khi tài xế giao; order được tạo thẳng. Chỉ method `requiresGateway = true` mới đi qua bloc.

---

## 14. Nơi cần đọc thêm

| Muốn hiểu | Đọc |
|---|---|
| Chi tiết UC-01..12 | `tasks/use-case-01-*.md` … `tasks/use-case-12-*.md` |
| Spec gốc của toàn bộ app (design system, component, mock JSON, HTML skeleton) | `tasks/agent.md` |
| Thiết kế Payment screen + quyết định kiến trúc | `docs/plans/2026-10-24-payment-screen-design.md` |
| Thiết kế Cart/Checkout | `docs/plans/2026-10-23-cart-checkout-design.md` |
| Quy ước nhóm + conflict matrix | `CONTRIBUTING.md`, `README.md` |
| Toạ độ Figma của Payment | `lib/presentation/client/payment/payment_geometry.dart` |
| Bảng màu & typography | `lib/presentation/themes/colors_frave.dart`, `type_frave.dart` |

---

## 15. Quick checklist cho agent

- [ ] Đọc `lib/router/app_router.dart` + `lib/main.dart` để nắm wiring bloc ↔ route
- [ ] Kiểm tra `flutter analyze` trước khi sửa (baseline: 62 info, 0 error)
- [ ] Mọi số tiền → dùng `CartPricing`, **không** hardcode
- [ ] Mọi màu → dùng `ColorsFrave`, **không** hex trực tiếp (trừ khi Figma node ghi rõ trong comment)
- [ ] Service mới → abstract interface + Firebase impl + fake trong test
- [ ] Bloc mới → 1 file + `part` event/state, không Freezed, không `emit` từ stream listener
- [ ] Màn hình mới → thêm route vào `app_router.dart` + cập nhật bảng route ở §7
- [ ] Test mới → đặt cạnh feature, theo pattern `test/*_bloc_test.dart` / `test/*_geometry_test.dart`
- [ ] Đụng Figma → cập nhật `docs/plans/` để không mất context

---

## 16. Ngôn ngữ & tiền tệ (bắt buộc)

> Thêm ngày 2026-10-24. Toàn bộ UI đã được chuyển sang tiếng Việt.

| Quy tắc | Chi tiết |
|---|---|
| **Nguồn chữ duy nhất** | `lib/l10n/app_vi.arb` — thêm/sửa chữ **ở đây**, không hardcode trong widget |
| **Cách đọc** | `context.l10n.<key>` (extension ở `lib/presentation/helpers/l10n_extension.dart`) |
| **Không có `BuildContext`** | `viL10n.<key>` — cùng bộ chữ, dùng cho static helper / top-level validator |
| **Sinh code** | `flutter gen-l10n` → `lib/l10n/generated/` (build artifact, **gitignored**) |
| **Fallback** | `context.l10n` tự trả về bản tiếng Việt khi chưa mount `Localizations` scope → widget test không cần cài delegate |
| **Tiền tệ** | Giá lưu trong DB là **USD**; hiển thị là **VND** qua `Money.format()` (`lib/presentation/helpers/money.dart`), tỉ giá `Environment.payosVndRate = 25000` |

### Bắt buộc khi thêm màn hình

1. Thêm key vào `lib/l10n/app_vi.arb` (tiếng Việt, có `@key` metadata cho placeholder).
2. Chạy `flutter gen-l10n`.
3. Dùng `context.l10n.key` — **không** viết chuỗi tiếng Anh trong `Text(...)`.
4. Số tiền → `Money.format(...)`, **không** format tay.

### Domain layer **không** chứa chữ hiển thị

Domain không được import l10n (giữ `data → domain → presentation` một chiều). Vì vậy các enum **không** mang label tiếng Anh nữa — chúng chỉ mang *id* ổn định, và presentation map sang tiếng Việt:

| Domain | Presentation map tại |
|---|---|
| `OrderFilter.id` | `client/orders/widgets/order_filter_chips.dart` (`_filterLabel`) |
| `OrderFilter` (enum value) | `client/orders/widgets/orders_empty_state.dart` (`_emptySubtitle`) |
| `OrderStage` (enum value) | `components/map/order_timeline.dart` (`_labelFor` / `_descriptionFor`) |
| `DriverVehicle` (enum value) | `components/map/driver_card.dart` (`_vehicleLabel`) |
| `MapClientState.etaMinutes` / `MapDeliveryState.etaMinutes` | `components/map/eta_bar.dart` (`etaLabelFor(l10n, minutes)`) |
| `TypePaymentMethod.uid` | `client/payment/widgets/payment_method_sheet.dart` (`paymentMethodLabel`) |

> Khi thêm giá trị mới cho các enum trên, **phải** thêm key tương ứng vào ARB và cập nhật hàm map trong presentation.
>
> Cấm `String` tiếng Anh trong `lib/domain/**` — dùng `Grep` để kiểm tra:
> `Grep` pattern `['\"][A-Z][a-z]+ [a-z]+` trong `lib/domain/` phải trả về **0** kết quả (trừ comment).

### 16.1 Catalogue Firebase — cũng phải là tiếng Việt

> Thêm ngày 2026-10-25. Lần chuyển UI sang tiếng Việt (2026-10-24) **bỏ sót dữ liệu trong Firebase** — mọi `nameProduct` / `description` / `category` vẫn là tiếng Anh. Đã migrate xong.

| Node | Trước | Sau |
|---|---|---|
| `delicia/products/{id}` | `nameProduct`, `description`, `category`, `restaurantName` (EN) | Tiếng Việt + thêm `nameProductEn` (tên EN gốc, **chỉ dùng để search**) |
| `delicia/categories/{id}` | `category`, `description` (EN) | Tiếng Việt |
| `delicia/orders/{id}/products/{n}/nameProduct` | Snapshot tiếng Anh | Tiếng Việt (snapshot copy lúc checkout, phải migrate riêng) |

**Quy tắc bất di bất dịch:**

1. **`categoryId` là khóa ổn định — KHÔNG đổi.** Nó là ASCII slug (`cat_burger`, `cat_pizza`…) và là chỉ mục cho `orderByChild('categoryId')`. Đổi nó là hỏng mọi filter theo danh mục.
2. **Không dùng tên hiển thị làm key.** `Productsdb.category` / `Category.category` giờ là tiếng Việt → không ổn định. Mọi logic "món này thuộc nhóm nào" phải key off `categoryId`.
   - Helper: `lib/presentation/helpers/category_assets.dart` (`CategoryAssets.photoFor` / `iconFor`)
   - Có fallback theo tên đã bỏ dấu để dòng legacy (tiếng Anh) vẫn render đúng.
3. **`status` của order không dịch.** `PAID OUT` / `DISPATCHED` / `ON WAY` / `DELIVERED` là *id* nội bộ — presentation map sang tiếng Việt ở `client/orders/widgets/`.
4. **Catalogue chuẩn:** `scripts/catalog_reference.json` — 27 món (`p01`–`p27`) + 7 danh mục (`cat_*`) + 4 size option; mỗi nhóm burger, pizza, đồ uống, tráng miệng và món lành mạnh có ít nhất 5 món. Đây là nguồn tham chiếu duy nhất cho một product row hoàn chỉnh (thay cho các script Python đã xoá). Bảo vệ bởi `test/catalog_integrity_test.dart`.
5. **Search khớp cả 2 ngôn ngữ:** `Productsdb.matchesQuery()` bỏ dấu + so khớp `nameProduct`, `description` **và** `nameProductEn`. Khách gõ "burger" vẫn ra "Burger Nấm Truffle Đặc Trưng".
6. **Bỏ dấu:** `lib/domain/utils/text_normalizer.dart` (`stripDiacritics`, `collapseWhitespace`) — dùng chung cho domain lẫn presentation.

### 16.2 Search — client-side, có ranking

> Sửa ngày 2026-10-26. Trước đó search gọi network **mỗi lần gõ** (`searchProducts()` → Firebase `once()`), trả kết quả theo thứ tự DB (không xếp hạng), và có 3 bug: query + category **không** lọc theo category, clear filter để lại màn hình trống, category đã chọn ở Home lọc sang cả Search.

**Kiến trúc (3 file, đều ở `lib/domain/utils/`):**

| File | Vai trò |
|---|---|
| `text_normalizer.dart` | `stripDiacritics`, `collapseWhitespace` — bỏ dấu + gộp whitespace |
| `search_matcher.dart` | **Leaf module** — luật thuần: `searchTokens()`, `fieldsMatch()`, `matchStrength()`, `SearchFields` |
| `product_search.dart` | Engine xếp hạng — `ProductSearch.filter/rank/matches`, `ProductSearchHit` |

> ⚠️ `search_matcher.dart` là **leaf** (không import model) để tránh circular import với `product.dart`. `product_search.dart` import model → OK. `Productsdb.matchesQuery()` delegate sang `search_matcher.dart` → **một nguồn luật duy nhất**.

**Luật match:**

1. **Token AND** — mọi từ trong query phải khớp ở ít nhất một field. Gõ "truffle burger" **không** trả về mọi món truffle *lẫn* mọi món burger.
2. Bỏ dấu + không phân biệt hoa thường → "bun bo" ra "Bún Bò".
3. Field theo thứ tự quan trọng: `nameProduct` (3.0) > `nameProductEn` (2.5) > `category` (1.5) > `description` (1.0).
4. Khớp càng sớm trong text càng mạnh (decay theo vị trí).
5. Tên ngắn hơn thắng khi hòa điểm (tie-break).
6. **Món hết hàng (`status != 1`) bị loại khỏi kết quả** — Home cũng ẩn, và card của món hết hàng vẫn có nút "+" nên không được phép hiện.

**Bloc (`products_bloc.dart`):**

- Search chạy **client-side** trên `state.allProducts` — không gọi network mỗi keystroke.
- `OnSearchProductEvent` — vẫn debounce 300 ms.
- `OnStartSearchEvent` — **mới**: mở màn hình search với slate sạch, không kế thừa category từ Home (Home và Search dùng chung 1 bloc).
- `OnClearCategoryEvent` — **mới**: bỏ filter category nhưng **giữ nguyên** query (chip `×` chỉ bỏ category, không xoá ô tìm kiếm).
- `OnClearSearchEvent` — reset filter **và** hiện lại toàn bộ catalogue (trước đó để trống màn hình).

**Presentation:**

- `lib/presentation/client/search/widgets/highlighted_text.dart` — highlight từ khoá (bỏ dấu-aware). `ProductCard` có tuỳ chọn `highlightQuery`.
- Số kết quả hiển thị dưới ô tìm kiếm (`searchResultCount` trong ARB).
- Nút `×` trong ô tìm kiếm + chip category → cùng gọi `_clearSearch()`.

**Test:** `test/product_search_test.dart` (23) · `test/search_matcher_test.dart` (16) · `test/highlighted_text_test.dart` (9) · `test/products_bloc_test.dart` (10) · `test/search_overflow_test.dart` (7).

**Gotcha:** `ProductsState.copyWith()` dùng `??` nên **không unset được** field nullable. `selectedCategoryName` cần cờ `clearSelectedCategoryName: true` mới xoá được — dùng quên thì chip category cũ vẫn còn trên màn hình.

**Khi thêm món/danh mục mới:** thêm vào `scripts/catalog_reference.json` (nguồn chuẩn) **và** `scripts/seed_catalog.json` (legacy ids `c1`–`c8`).

> ⚠️ Không còn script Python trong repo (đã xoá 2026-10-26). Mọi thao tác ghi Firebase phải **đọc row sống → merge → `PUT` document đầy đủ**.
>
> ⚠️ REST API của RTDB **từ chối `PATCH` với body là JSON string thuần** — chỉ nhận object. Với một giá trị đơn phải dùng `PUT`.

### 16.3 Greeting theo buổi — clock phải tiêm vào

> Sửa ngày 2026-10-26. Header home có câu "Chào buổi sáng / chiều / tối" (`greetingMorning` / `greetingAfternoon` / `greetingEvening` trong ARB). Trước đây nó đọc `DateTime.now().hour` **trực tiếp**, nên ảnh golden đổi theo giờ chạy test → `home_golden_test.dart` và `home_positions_test.dart` fail với `0.24%, 787px diff` tuỳ giờ trong ngày.

**Cơ chế:** `ClientHomeScreen` nhận tham số `clock` (`HomeClock = DateTime Function()`), mặc định `null` → dùng `DateTime.now()` thật. App không đổi hành vi; chỉ test ghim clock.

```dart
// lib/presentation/client/home/home_screen.dart
typedef HomeClock = DateTime Function();

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key, this.clock});
  final HomeClock? clock;
}

// trong State
String _greeting(BuildContext context) {
  final now = (widget.clock ?? DateTime.now)();
  final hour = now.hour;
  final l10n = context.l10n;
  if (hour < 12) return l10n.greetingMorning;
  if (hour < 18) return l10n.greetingAfternoon;
  return l10n.greetingEvening;
}
```

**Quy ước:**
- Mọi test render `ClientHomeScreen` **phải** truyền `clock` cố định → dùng `test/helpers/home_clock.dart` (`fixedHomeClock` = 2024-01-15 09:00, `const` nên dùng được với `const ClientHomeScreen`).
- **Không** hardcode giờ trong app; app vẫn dùng đồng hồ thật.
- Bucket: `<12` sáng · `12..17` chiều · `>=18` tối.

**Test:** `test/home_greeting_test.dart` (5) — kiểm cả 3 bucket + chứng minh clock tiêm vào thắng đồng hồ thật.

> ⚠️ Baseline golden **không** bị "hack" theo giờ hiện tại: sau khi ghim clock, ảnh regenerate ra **giống hệt byte-for-byte** baseline cũ (`home_golden.png` / `home_positions_golden.png` không đổi) → chứng minh layout không đổi, chỉ là nguồn giờ thay đổi.

---

## 17. Vì sao agent phản hồi chậm — và cách tránh

> Chẩn đoán ngày 2026-10-24. **Năm** nguyên nhân, đã xử lý triệt để.

### 1. ~45 MB ảnh thiết kế bị index mỗi lượt (đã sửa)

`assets/Food Delivery App UI Kit .../` chứa ~40 ảnh PNG 8K. Chúng **không bao giờ** được agent đọc (là ảnh nhị phân), nhưng Cursor vẫn glob + index + liệt kê chúng mỗi lượt — ăn hết budget của tool call trước khi tới code.

→ Đã thêm vào `.gitignore` (Cursor index theo `.gitignore`):
`assets/Food Delivery App UI Kit .../`, `assets/figma_raw/`, `test/_*.png`, `test/failures/`, `.tmpfig/`, `lib/l10n/generated/`.

> ⚠️ **Không** gitignore `assets/figma_home/`, `assets/figma_cart/`, `assets/figma_payment/`, `assets/fonts/` — app build cần chúng.

### 2. `tasks/agent.md` nặng 217 KB (đã gitignore, vẫn đọc được)

File này là spec gốc của toàn bộ app. Đã đưa vào `.gitignore` (nó vốn đã nằm trong ignore list `tasks/`).

- Muốn đọc → dùng `Grep` với pattern cụ thể, **đừng** `Read` toàn bộ file.
- Nội dung quan trọng đã được rút gọn vào §1–§17 của file này.

### 3. `git status` lẫn hàng trăm file rác (đã sửa)

Trước đây `git status` trả về **157 dòng untracked** (build cache, probe PNG, task spec). Mỗi lượt agent đọc status đều phải parse hết.

→ Sau khi dọn `.gitignore`: **136 dòng** (phần lớn là code thật đang sửa).

### 4. Probe/scratch files trong repo (đã xoá hết — 2026-10-26)

Các file probe tạm do agent sinh ra khi eyeball layout: `test/_*.dart`, `test/_crops/`, `test/_*.png`, `test/_*.json`, `scripts/_*.py`, `scripts/_*.ps1`, `tool/`, `screenshots/`, `scripts/ui_dump.xml`.

→ Đã **xoá hết** (~120 file, 4+ MB). Quy tắc: file bắt đầu bằng `_` trong `test/`/`scripts/`, cùng mọi thư mục `test/_crops/`, `screenshots/`, `tool/` là **rác** — xoá ngay sau khi dùng, không để lại.

> ⚠️ **User yêu cầu rõ ràng: KHÔNG tạo probe test.** Agent không được viết file test tạm để probe hành vi (ví dụ `_probe_test.dart`), không được dump screenshot/UI hierarchy ra file, không được tạo script Python/PS để đo pixel. **User tự test.** Viết test thật, đặt tên đúng quy ước (`test/<feature>_test.dart`) và track được — hoặc không viết test gì cả.
>
> Nếu cần kiểm tra gì đó, dùng `flutter analyze` / `flutter test` trên test có sẵn, hoặc hỏi user. Đừng tạo file scratch.

### 5. Log Cursor cũ tích tụ 39 MB (đã sửa)

`%APPDATA%\Cursor\logs\` giữ log của **mọi** session trước đó, mỗi session vài MB (requestTrace, git extension, agent-host log).

→ Đã xóa 9 session cũ, giữ lại session hiện tại: **39 MB → 8 MB**.

> ⚠️ Log này **tự sinh lại** theo thời gian. Nếu agent tiếp tục chậm, kiểm tra lại thư mục này trước khi tìm nguyên nhân khác.
> Cũng vậy: `%APPDATA%\Cursor\User\workspaceStorage\*\redhat.java\jdt_ws\` (~40 MB) là cache Java của Android Studio — không ảnh hưởng agent, nhưng có thể xóa nếu cần tiết kiệm đĩa.

### Quy tắc cho agent

| Nên | Không nên |
|---|---|
| Dùng `Grep` với pattern cụ thể để tìm chỗ cần sửa | `Read` cả file 200+ dòng chỉ để tìm 1 chỗ |
| Đọc `lib/l10n/app_vi.arb` (file gốc, ~400 dòng) | Đọc `lib/l10n/generated/` — file sinh tự động |
| `flutter analyze` + `flutter test` để verify | Đọc lại toàn bộ repo sau mỗi edit |
| Batch nhiều `Read`/`Grep` trong **một** message | Gọi tool tuần tự từng cái một |
| Delegate phần lặp lại (mass refactor nhiều file) cho subagent | Tự làm từng file khi >10 file giống nhau |
| Xóa file scratch (`_*`) ngay sau khi dùng | Để lại PNG/Python probe trong `test/` |
| **Không tạo probe test** — user tự test | Viết `_probe_test.dart`, dump screenshot, script đo pixel |
| Dùng `Grep` để tìm file cần xóa | Dùng `Shell` + `Get-ChildItem` để scan đệ quy toàn repo |

### Delegation cho subagent (kinh nghiệm từ lần refactor này)

Subagent rất hiệu quả cho **mass refactor 10–15 file cùng kiểu**. Nhưng:

- **Bắt buộc** chỉ định rõ: file nào được sửa, file nào **không** được sửa.
- **Bắt buộc** yêu cầu chạy `flutter analyze` + `flutter test` và báo cáo số lượng.
- Lần này subagent đã tạo **98 test fail** vì dùng `context.l10n` trong test harness không cài `AppLocalizations.delegate`. → Đã sửa bằng cách làm `context.l10n` **null-safe** (`l10n_extension.dart`), thay vì sửa 20+ file test.
- Nếu subagent báo "98 fail nhưng không phải regression", **phải tự kiểm chứng** bằng `flutter test` trước khi tin.

### Test hộ giữ (contract tests) chống tái phát

| File | Chống cái gì |
|---|---|
| `test/l10n_test.dart` | ARB lệch với generated class · giá trị còn tiếng Anh · placeholder thiếu metadata |
| `test/money_test.dart` | `Money.format` / `formatVnd` / `toVnd` (USD→VND, `322.500 ₫`) |

> `test/l10n_test.dart` đọc trực tiếp `lib/l10n/app_vi.arb` nên **tự động** cover key mới — thêm key vào ARB mà chưa `flutter gen-l10n` sẽ fail ngay.

