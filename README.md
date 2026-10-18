# Delicia — Flutter Food Delivery App

> App đặt đồ ăn nhiều role: **Client** đặt món, **Admin** (nhà hàng) quản lý menu/đơn, **Delivery** nhận & giao đơn.
> Stack: **Flutter 3.47** + **Firebase** (Auth + Realtime Database + Storage) + **OpenStreetMap** (via flutter_map, no API key) + **Firebase RTDB realtime** (no separate socket server) + **Stripe** (mock).

---

## 🚀 Quick Start

```bash
# 1. Cài Flutter SDK 3.47+ (https://docs.flutter.dev/get-started/install)
flutter --version          # phải >= 3.47.0

# 2. Clone + cài deps
git clone https://github.com/<your-org>/delicia.git
cd delicia
flutter pub get

# 3. Thêm Firebase config (KHÔNG có sẵn trong repo)
# - Android: copy android/app/google-services.json (lấy từ Firebase Console)
# - iOS:     copy ios/Runner/GoogleService-Info.plist

# 4. Chạy
flutter run -d <device-id>
```

> Chi tiết: xem [`docs/setup.md`](docs/setup.md) (sẽ tạo sau khi team merge xong setup branch).

---

## 🏗️ Architecture

```
lib/
├── data/                  # Infrastructure: env, storage, API config, services
│   ├── env/environment.dart
│   ├── local_secure/secure_storage.dart
│   └── services/          # AuthService, ProductsService, OrdersService, RealtimeService, NotificationService, ...
├── domain/                # Business logic
│   ├── models/            # User, Product, Order, Address, DeliveryStatus, ...
│   ├── repositories/      # ProductRepository, OrderRepository, ...
│   └── bloc/              # auth/, products/, orders/, cart/, map_client/, map_delivery/, address/, user/, dashboard/, delivery/, category/, ...
├── presentation/          # UI layer
│   ├── components/        # BtnFrave, FormFieldFrave, TextCustom, ...
│   ├── helpers/           # modalLoading, errorMessageSnack, ...
│   ├── screens/           # intro/, login/, client/, admin/, delivery/
│   ├── themes/colors_frave.dart
│   └── animations/
├── router/app_router.dart # GoRouter (10 routes)
└── main.dart              # MultiBlocProvider + MaterialApp.router
```

**Pattern:** BLoC + Repository + GoRouter. Mỗi role có folder screens riêng (`client/`, `admin/`, `delivery/`).

---

## 👥 Team & Phân Công 12 Use-Cases

| Member | Branch | Use cases | Status |
|---|---|---|---|
| **Leader (D)** | `feat/leader-core` | UC-01 Auth ✓, UC-02 Home, UC-03 Map, UC-04 Cart/Checkout, UC-12 Polish/Deploy | UC-01 done, còn lại in progress |
| **Member A** | `feat/client-flow` | UC-05 Orders, UC-06 Profile/Addresses | 🔄 in progress |
| **Member B** | `feat/admin-flow` | UC-07 Dashboard, UC-08 CRUD, UC-09 Orders Mgmt | 🔄 in progress |
| **Member C** | `feat/delivery-flow` | UC-10 Delivery Home, UC-11 State Machine | 🔄 in progress |

**Luồng end-to-end (Leader tự test, không phụ thuộc team):**
```
UC-02 (Home + Browse) → Add to Cart → UC-04 (Cart/Checkout)
     → tạo Order → UC-03 (Map track delivery realtime)
```

**File conflict matrix (xem chi tiết trong `tasks/team-assignment.txt`):**
- `lib/presentation/client/cart/`, `checkout/` → Leader (UC-04)
- `lib/presentation/client/home/`, `product_detail/` → Leader (UC-02)
- `lib/presentation/client/orders/`, `profile/` → Member A
- `lib/presentation/admin/**` → Member B
- `lib/presentation/delivery/home/`, `details/` → Member C
- `lib/presentation/client/map/`, `delivery/map/` → Leader (UC-03)
- `lib/data/services/socket_service.dart` → Leader (UC-03)
- `lib/domain/bloc/map_client/`, `map_delivery/` → Leader (UC-03)
- `lib/domain/bloc/cart/` → Leader (UC-04)
- `lib/domain/bloc/orders/` → A (read/cancel) + Leader (create) + B (admin view) — mỗi người PR riêng
- File chung (`main.dart`, `app_router.dart`, `pubspec.yaml`, `AndroidManifest.xml`, `environment.dart`) → PR riêng, Leader merge

---

## 🔥 Firebase

- **Project:** `delicia-60e0a`
- **Realtime Database:** `https://delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app`
- **Auth providers cần enable:** Email/Password
- **Firestore:** chưa dùng (đang dùng Realtime DB)
- **Storage:** dùng cho upload ảnh category/product (UC-08) + ảnh giao hàng (UC-11)
- **Cloud Messaging (FCM):** UC-12 — push notification khi order mới / delivery update

### Test accounts (seeded)

| Email | Password | Role | Note |
|---|---|---|---|
| `darklunatv@gmail.com` | (đã đăng ký) | Client (2) | UC-01 verified |
| `admin@delicia.com` | (sẽ tạo) | Admin (1) | UC-07 |
| `delivery@delicia.com` | (sẽ tạo) | Delivery (3) | UC-10 |

---

## 🧪 Test

```bash
flutter test                                    # toàn bộ unit + widget tests
flutter test test/features/auth/                # chỉ test auth
flutter test test/features/client/cart/         # chỉ test cart (UC-04)
flutter test test/features/delivery/            # chỉ test delivery (UC-10/11)
flutter test --coverage                         # coverage report
```

**Mục tiêu cuối:** mỗi feature có unit test (bloc) + widget test (screen). Hiện tại: 8/8 tests PASS (auth_bloc_test.dart).

**Phân chia test:**
- A tự viết test cho UC-05, UC-06
- B tự viết test cho UC-07, UC-08, UC-09
- C tự viết test cho UC-10, UC-11
- Leader tự viết test cho UC-02, UC-03, UC-04

---

## 📦 Build

```bash
flutter build apk --debug                      # debug APK
flutter build apk --release                    # release APK (cần keystore — UC-12)
flutter build appbundle --release              # AAB cho Play Store
flutter build ipa --release                    # iOS
```

APK debug hiện tại: `build/app/outputs/flutter-apk/app-debug.apk` (~165 MB).

---

## 🚢 Deploy (UC-12)

- **CI:** GitHub Actions — analyze + test + build APK tự động (`.github/workflows/ci.yml`)
- **Distribution:** Firebase App Distribution (testing)
- **Production:** Google Play Console (AAB)

---

## 🐛 Troubleshooting

| Lỗi | Fix |
|---|---|
| `màn hình đen khi mở app` | Plugin `com.google.gms.google-services` chưa apply ở `:app`. Xem commit fix. |
| `Database lives in a different region` | Set `databaseURL` trong `lib/data/env/environment.dart` = `https://delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app` |
| `Can't sign out` | App dùng GoRouter — dùng `context.go('/intro')` thay vì `Navigator.popUntil()`. |
| `BLASTBufferQueue: Can't acquire next buffer` | Vendor noise (Vivo), bỏ qua. |
| `Map không hiển thị` | Kiểm tra `Environment.tileServerUrl` (mặc định OSM) + Internet permission |
| `Realtime không update` | Kiểm tra `Environment.firebaseDatabaseUrl` + quyền read/write RTDB |

---

## 📜 License

Internal project — chưa public.
