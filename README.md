# Delicia — Flutter Food Delivery App

> App đặt đồ ăn nhiều role: **Client** đặt món, **Admin** (nhà hàng) quản lý menu/đơn, **Delivery** nhận & giao đơn.
> Stack: **Flutter 3.47** + **Firebase** (Auth + Realtime Database + Storage) + **Google Maps** + **Stripe** (mock).

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
├── data/                  # Infrastructure: env, storage, API config
│   ├── env/environment.dart
│   └── local_secure/secure_storage.dart
├── domain/                # Business logic
│   ├── models/            # User, Product, Order, Address, ...
│   ├── services/          # AuthService, ProductsService, OrdersService, ...
│   └── bloc/              # auth/, products/, orders/, cart/, ...
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

## 👥 Team & Branches

| Member | Branch(es) | Use cases | Status |
|---|---|---|---|
| **Leader (D)** | `feat/uc-01-auth`, `feat/uc-02-home` | Auth, Client Home | ✅ merged (UC-01 done) |
| **Member A** | `feat/uc-04-cart`, `feat/uc-05-orders`, `feat/uc-06-profile` | Cart, Orders, Profile | 🔄 in progress |
| **Member B** | `feat/uc-07-admin-home`, `feat/uc-08-admin-crud`, `feat/uc-09-admin-orders` | Admin Dashboard, CRUD, Orders Mgmt | 🔄 in progress |
| **Member C** | `feat/uc-03-map`, `feat/uc-10-delivery-list`, `feat/uc-11-delivery-details`, `feat/uc-12-polish` | Map, Delivery, Polish/Deploy | 🔄 in progress |

> **Chi tiết từng use-case + acceptance criteria:** xem `tasks/use-case-*.md` (chỉ có ở local dev).

---

## 🔥 Firebase

- **Project:** `delicia-60e0a`
- **Realtime Database:** `https://delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app`
- **Auth providers cần enable:** Email/Password
- **Firestore:** chưa dùng (đang dùng Realtime DB)

### Test accounts (seeded)

| Email | Password | Role | Note |
|---|---|---|---|
| `darklunatv@gmail.com` | (đã đăng ký) | Client (2) | UC-01 verified |
| `admin@delicia.com` | (sẽ tạo) | Admin (1) | UC-07 |
| `delivery@delicia.com` | (sẽ tạo) | Delivery (3) | UC-10 |

---

## 🧪 Test

```bash
flutter test                        # unit + widget tests
flutter test test/features/auth/    # chỉ test auth
flutter test --coverage             # coverage report
```

**Hiện tại:** 8/8 tests PASS (auth_bloc_test.dart).

---

## 📦 Build

```bash
flutter build apk --debug                      # debug APK
flutter build apk --release                    # release APK (cần keystore)
flutter build appbundle --release              # AAB cho Play Store
flutter build ipa --release                    # iOS
```

APK debug hiện tại: `build/app/outputs/flutter-apk/app-debug.apk` (~165 MB).

---

## 🐛 Troubleshooting

| Lỗi | Fix |
|---|---|
| `màn hình đen khi mở app` | Plugin `com.google.gms.google-services` chưa apply ở `:app`. Xem commit fix. |
| `Database lives in a different region` | Set `databaseURL` trong `lib/data/env/environment.dart` = `https://delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app` |
| `Can't sign out` | App dùng GoRouter — dùng `context.go('/intro')` thay vì `Navigator.popUntil()`. |
| `BLASTBufferQueue: Can't acquire next buffer` | Vendor noise (Vivo), bỏ qua. |

---

## 📜 License

Internal project — chưa public.
