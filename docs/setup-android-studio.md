# Hướng dẫn chạy & test Delicia trên Android Studio

> Dành cho Member A (UC-05 Orders + UC-06 Profile/Addresses).
> Tài liệu này mô tả đúng cấu hình máy đã được setup sẵn.

---

## 0. Tóm tắt cấu hình máy (đã setup sẵn)

| Thành phần | Giá trị | Ghi chú |
|---|---|---|
| Flutter SDK | `F:\flutter` (3.47.0 stable) | **Không có khoảng trắng** — bắt buộc |
| Android SDK | `F:\Tool` | SDK 36.0.0, build-tools 36.0.0 |
| JDK | `F:\FPT Uni\Ky_8\Tools\jbr` (OpenJDK 25) | Bundled với Android Studio |
| Android Studio | 2026.1.3 | `C:\Program Files\Android\Android Studio` |
| Emulator | `Pixel_6a` — API 34, 1080x2400 | Đã tạo sẵn |
| Project | `F:\FPT Uni\Ky_8\PRM393\delicia-main` | |
| Package name | `com.example.delicia` | |

Các file đã được chỉnh sửa:

- `android/local.properties` → `flutter.sdk=F:\\flutter`, `sdk.dir=F:\\Tool`
- `android/gradle.properties` → thêm `kotlin.incremental=false` (fix lỗi Kotlin 2.x + Gradle 9)
- `android/app/build.gradle.kts` → thêm `firebase-storage`
- `android/app/src/main/AndroidManifest.xml` → thêm permission đọc ảnh
- `lib/data/env/environment.dart` → thêm `Environment.usersRoot = 'users'`
- `lib/domain/services/user_service.dart`, `address_service.dart` → dùng `usersRoot`

---

## 1. BƯỚC BẮT BUỘC: copy `google-services.json`

Hiện tại `android/app/google-services.json` là **file placeholder** (project `delicia-60e0a`
nhưng `project_number` / `api_key` đều là giá trị giả). App build được nhưng **không đăng nhập
được** vì Firebase Auth từ chối API key sai.

### Lấy file từ Firebase Console

1. Mở <https://console.firebase.google.com>
2. Chọn project **`delicia-60e0a`** (đúng project — không phải `prmse02`)
3. Vào ⚙️ **Project settings** (biểu tượng bánh răng) → tab **Your apps**
4. Nếu chưa có app Android: bấm **Add app → Android**
   - Package name: `com.example.delicia` ← **phải khớp chính xác**
   - Bỏ qua "Download Google Services file", bấm **Register app**
5. Quay lại tab **Your apps**, bấm biểu tượng Android (📱) cạnh app `com.example.delicia`
6. Bấm **Download google-services.json**

### Copy vào project

```
Source: file vừa tải (thường ở ~/Downloads)
Target: F:\FPT Uni\Ky_8\PRM393\delicia-main\android\app\google-services.json
```

Kiểm tra file đã đúng project:

```powershell
Get-Content "F:\FPT Uni\Ky_8\PRM393\delicia-main\android\app\google-services.json" |
  Select-String 'project_id|mobilesdk_app_id|package_name|current_key'
```

Phải thấy:
- `project_id` : `delicia-60e0a`
- `package_name` : `com.example.delicia`
- `mobilesdk_app_id` : dạng `1:<project_number>:android:<hash>` (KHÔNG phải `0:000...`)
- `current_key` : `AIzaSy...` (KHÔNG chứa chữ `PLACEHOLDER`)

> **Lưu ý:** file này chứa API key — `.gitignore` đã loại sẵn, **không push lên GitHub**.

### Bật Authentication trong Firebase Console (nếu chưa bật)

1. Firebase Console → **Authentication** → **Sign-in method**
2. Bật **Email/Password**
3. **Realtime Database** → Rules → dùng chế độ test:
   ```json
   { "rules": { ".read": true, ".write": true } }
   ```
   (Chỉ dùng khi demo. Production phải giới hạn theo `auth.uid`.)
4. **Storage** → Rules → cùng kiểu:
   ```json
   { "rules": { ".read": true, ".write": true } }
   ```

---

## 2. Mở project trong Android Studio

1. **Mở Android Studio** → màn hình Welcome
2. Chọn **Open** (hoặc `File → Open`)
3. Paste đường dẫn:
   ```
   F:\FPT Uni\Ky_8\PRM393\delicia-main
   ```
4. Bấm **OK** → chờ Gradle sync (lần đầu ~3–5 phút)

### Cài plugin Flutter & Dart

Nếu Android Studio báo "Flutter SDK is not found":

1. `File → Settings → Plugins` (Ctrl+Alt+S)
2. Tab **Marketplace**, tìm:
   - **Flutter** → Install → Restart IDE
   - **Dart** → Install
3. `Settings → Languages & Frameworks → Flutter`
   - Flutter SDK path: `F:\flutter`
   - Bấm **OK**

### Set JDK (nếu Gradle báo lỗi Java)

`Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK`
→ chọn `F:\FPT Uni\Ky_8\Tools\jbr`

> Hoặc chạy trong Terminal:
> ```powershell
> flutter config --jdk-dir="F:\FPT Uni\Ky_8\Tools\jbr"
> ```

---

## 3. Chạy test tự động (82 test)

Mở Terminal trong Android Studio (`Alt+F12`) hoặc Terminal của Cursor:

```powershell
cd "F:\FPT Uni\Ky_8\PRM393\delicia-main"

# Toàn bộ test
flutter test

# Chỉ test UC-05
flutter test test/client_orders_bloc_test.dart test/orders_list_widget_test.dart test/order_detail_widget_test.dart test/order_status_timeline_widget_test.dart

# Chỉ test UC-06
flutter test test/user_bloc_test.dart test/address_bloc_test.dart test/profile_widget_test.dart test/address_widgets_test.dart

# Coverage
flutter test --coverage
```

Kết quả mong đợi: **`00:0X +82: All tests passed!`**

Trên Android Studio, bạn cũng có thể bấm chuột phải vào thư mục `test/` → **Run 'test'** để
chạy trong Test Runner window (có cây test + hiển thị lỗi chi tiết).

Kiểm tra chất lượng code:

```powershell
flutter analyze      # kỳ vọng: No issues found!
dart format lib test
```

---

## 4. Tạo & chạy Emulator

### 4.1 Emulator đã có sẵn (`Pixel_6a`)

```powershell
# Liệt kê emulator
flutter emulators

# Khởi động
flutter emulators --launch Pixel_6a

# Hoặc mở trực tiếp trong Android Studio:
#   View → Tool Windows → Device Manager → Pixel_6a ▶
```

Đợi ~45 giây cho tới khi màn hình home emulator hiện ra.

Kiểm tra Flutter đã nhận emulator:

```powershell
flutter devices
# Kết quả mong đợi:
#   sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64 • Android 14 (API 34) (emulator)
```

### 4.2 Tạo emulator mới (nếu cần)

`Device Manager` (biểu tượng điện thoại) → **+ Create Virtual Device** → chọn device
(Pixel 6a) → System Image **API 34, x86_64** → Finish.

### 4.3 Dùng máy thật (USB)

1. Trên điện thoại: Settings → About → bấm 7 lần vào **Build number** → bật Developer mode
2. Settings → Developer options → bật **USB debugging**
3. Cắm USB, chọn chế độ **File transfer (MTP)**
4. Trên điện thoại chấp nhận popup "Allow USB debugging"
5. `flutter devices` phải thấy tên máy

---

## 5. Chạy app

### 5.1 Từ Android Studio (GUI)

1. Bấm dropdown thiết bị góc trên (phải chọn `Pixel_6a` / `emulator-5554`)
2. Chọn run configuration **`main.dart`** (đã có sẵn trong `.idea/workspace.xml`)
3. Bấm nút ▶ (Run) góc trên bên phải, hoặc **Shift+F10**

Lần đầu build lâu (~2–3 phút). Sau đó:

| Phím tắt | Tác dụng |
|---|---|
| `r` | Hot Reload (sửa UI, giữ state) |
| `R` | Hot Restart (reset state) |
| `q` | Thoát app |
| `o` | Toggle Android / iOS |

### 5.2 Từ Terminal (khuyến nghị khi debug)

```powershell
cd "F:\FPT Uni\Ky_8\PRM393\delicia-main"
flutter run -d emulator-5554
```

Thêm `--verbose` nếu cần log chi tiết. Dừng app: `q`.

### 5.3 Build APK để cài lên máy thật

```powershell
flutter build apk --debug
# → build\app\outputs\flutter-apk\app-debug.apk  (~171 MB)

flutter build apk --release   # cần keystore (UC-12)
flutter build appbundle --release
```

Cài lên máy:

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

---

## 6. Kịch bản test UC-05 (Client Orders)

### Bước 1 — Đăng nhập

1. App mở ra màn hình **Intro** ("Delicia / Food delivered to your door")
2. Bấm **Skip** → màn hình Login
3. Bấm **Create an account** → đăng ký tài khoản mới (hoặc dùng account có sẵn)
4. Đăng ký xong sẽ tự ghi profile vào `users/{uid}`

> Tài khoản có sẵn trong DB: `darklunatv@gmail.com` (uid `YBumGSbpmZbtyXRer4jagBtie8D3`)

### Bước 2 — Mở màn hình Orders

Từ **Home** screen, bấm biểu tượng **hộp/list ở góc trên** → route `/client/orders`.

Kiểm tra:
- [ ] AppBar có tiêu đề "My Orders"
- [ ] Có **2 tab: Active / History**
- [ ] Icon **wifi-tethering** ở AppBar = realtime đang bật (nếu là icon refresh = chưa bật)
- [ ] Tab **Active** hiện các đơn chưa giao (`PAID OUT`, `DISPATCHED`, `ON WAY`)
- [ ] Tab **History** hiện `DELIVERED` + `CANCELLED`
- [ ] Mỗi card hiện: tên sản phẩm, số lượng, tổng tiền, status badge, thời gian tương đối ("2h ago")
- [ ] Pull-to-refresh (kéo xuống) reload được danh sách

### Bước 3 — Màn hình chi tiết đơn hàng

Bấm vào 1 card → route `/client/orders/detail/:id`.

Kiểm tra:
- [ ] **Timeline** 4 bước: PAID OUT → DISPATCHED → ON WAY → DELIVERED
- [ ] Bước hiện tại được highlight (màu primary + icon check)
- [ ] Bước tương lai hiển thị mờ
- [ ] Danh sách sản phẩm (tên, số lượng, giá)
- [ ] Tổng tiền, phương thức thanh toán, địa chỉ giao hàng
- [ ] Nút **Cancel order** chỉ hiện khi status = `PAID OUT` (status khác → nút ẩn)

### Bước 4 — Realtime update

Mở Firebase Console → **Realtime Database** → `delicia/orders/{orderId}`,
đổi `status` từ `PAID OUT` → `DISPATCHED`.

Kiểm tra: màn hình detail **tự cập nhật trong ~1–2 giây** (không cần refresh),
timeline tiến lên 1 bước.

### Bước 5 — Hủy đơn

Trên đơn có status `PAID OUT`, bấm **Cancel order** → xác nhận.

Kiểm tra:
- [ ] Status đổi thành `CANCELLED`
- [ ] Đơn **biến mất khỏi tab Active** và **xuất hiện ở tab History**
- [ ] Trong Firebase Console, `status` = `CANCELLED`

### Bước 6 — Tạo đơn mới để test

Đi theo luồng của Leader (UC-02 → UC-04):
Home → chọn sản phẩm → **Add to cart** → icon giỏ hàng → **Checkout** → **Place order**.
Sau khi checkout xong, quay lại tab Orders → đơn mới phải xuất hiện ngay (realtime).

---

## 7. Kịch bản test UC-06 (Profile & Addresses)

### Bước 1 — Mở Profile

Từ Home screen, bấm **avatar** ở góc trên → route `/client/profile`.

Kiểm tra:
- [ ] Avatar hiển thị (hoặc chữ cái đầu nếu chưa có ảnh)
- [ ] First name / Last name / Email / Phone hiển thị **đúng dữ liệu từ Firebase**
- [ ] Email ở trạng thái **read-only** (không sửa được)
- [ ] Nút **Save changes**, **Manage addresses**, **Sign out**

> ⚠️ Nếu hiện "Profile not found" → kiểm tra lại `google-services.json` và user đã đăng nhập.

### Bước 2 — Sửa profile

1. Sửa First name / Last name / Phone
2. Bấm **Save changes** → hiện "Saving…" rồi thành công
3. Verify: Firebase Console → `users/{uid}` → `firstName` / `lastName` / `phone` đã đổi
4. **Thử bỏ trống First name** → bấm Save → phải hiện lỗi *"First name is required"*
   (validation của `FormFieldFrave`)

### Bước 3 — Upload avatar

1. Bấm vào vòng tròn avatar (hoặc nút đổi ảnh)
2. Hệ thống mở **Photo Picker** của Android → chọn 1 ảnh
3. App upload lên Firebase Storage (`avatars/{uid}.jpg`)
4. Kiểm tra:
   - [ ] Có spinner "Uploading…" trong lúc upload
   - [ ] Avatar hiển thị ảnh vừa chọn
   - [ ] Firebase Console → **Storage** → `avatars/{uid}.jpg` tồn tại
   - [ ] `users/{uid}.image` trong Realtime DB = URL download

> Nếu upload lỗi: kiểm tra Storage Rules trong Firebase Console đã bật (bước 1.4).

### Bước 4 — Danh sách địa chỉ

Bấm **Manage addresses** → route `/client/profile/addresses`.

Kiểm tra:
- [ ] AppBar "My Addresses"
- [ ] Nếu chưa có địa chỉ → empty state + nút **Add address**
- [ ] Địa chỉ mặc định (isDefault) hiện **đầu danh sách** + badge "Default"

### Bước 5 — Thêm địa chỉ

Bấm **Add address** → màn hình form:

| Trường | Bắt buộc | Ghi chú |
|---|---|---|
| Street | ✅ | Bỏ trống → lỗi "Street is required" |
| Reference (optional) | ❌ | Ví dụ "Quận 1, TP.HCM" |
| Latitude | ❌ | Mặc định gợi ý `10.7717` |
| Longitude | ❌ | Mặc định gợi ý `106.7009` |

Bấm **Add address** → quay lại danh sách, địa chỉ mới hiện ở đầu.
Verify Firebase Console: `users/{uid}/addresses/{addressId}` có `street`, `reference`,
`latitude`, `longitude`.

### Bước 6 — Sửa / Set default / Xoá

- **Edit** → đổi Street → **Save changes** → danh sách cập nhật ngay
- **Set default** → địa chỉ đó lên đầu list + badge Default, **địa chỉ cũ mất badge**
  (chỉ 1 địa chỉ default tại một thời điểm)
- **Delete** → popup "Delete address?" → **Cancel** (đóng, không xoá) hoặc xác nhận →
  địa chỉ biến mất khỏi list + biến mất trong Firebase

### Bước 7 — Đăng xuất

Bấm **Sign out** → popup xác nhận:
- **Stay** → đóng popup, giữ phiên đăng nhập
- **Sign out** → quay về màn hình Intro, đăng nhập lại thấy trạng thái profile sạch

---

## 8. Kiểm tra dữ liệu trực tiếp trên Firebase Console

| Tính năng | Đường dẫn trong Realtime Database |
|---|---|
| Profile (UC-06) | `users/{uid}` |
| Địa chỉ (UC-06) | `users/{uid}/addresses/{addressId}` |
| Đơn hàng (UC-05) | `delicia/orders/{orderId}` |
| Danh mục / sản phẩm | `delicia/categories`, `delicia/products` |
| Vị trí shipper | `delicia/orders/{orderId}/shipperLocation` |

> Lưu ý: profile + địa chỉ nằm ở `users/...` (không có prefix `delicia/`) vì
> `AuthService` của Leader ghi profile vào `users/{uid}` — code UC-06 đã thống nhất
> theo node này.

---

## 9. Xử lý sự cố

| Triệu chứng | Nguyên nhân | Cách sửa |
|---|---|---|
| `Could not close incremental caches` | Kotlin 2.x + Gradle 9 | Đã fix bằng `kotlin.incremental=false` trong `android/gradle.properties`. Nếu lặp lại: xoá `build/` rồi build lại |
| `File google-services.json is missing` | Chưa copy file | Xem mục 1 |
| `Error from api_key` / `API key not valid` | Placeholder hoặc sai project | Tải lại file đúng `delicia-60e0a` |
| `Profile not found` | User chưa có node trong `users/` | Đăng ký lại, hoặc kiểm tra user đăng nhập có `users/{uid}` chưa |
| `Database lives in a different region` | Sai `databaseURL` | `Environment.firebaseDatabaseUrl` phải là `https://delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app` |
| Màn hình đen khi mở app | Thiếu plugin google-services | Đã apply ở `android/app/build.gradle.kts` |
| Không đăng nhập được | Email/Password chưa bật | Firebase Console → Authentication → Sign-in method → bật Email/Password |
| Upload avatar lỗi | Storage Rules chặn | Sửa Rules thành `{"rules":{".read":true,".write":true}}` (demo) |
| `flutter` không chạy trong Terminal | PATH sai | Thêm `F:\flutter\bin` vào PATH, hoặc dùng đường dẫn đầy đủ |
| Gradle sync lỗi Java version | JDK sai | `flutter config --jdk-dir="F:\FPT Uni\Ky_8\Tools\jbr"` |
| Emulator không khởi động | AVD lỗi | Device Manager → Wipe Data, hoặc tạo AVD mới API 34 |
| Build chậm quá 5 phút | Lần build đầu | Bình thường, các lần sau ~1–2 phút |

---

## 10. Checklist bàn giao

- [ ] `google-services.json` thật đã được copy vào `android/app/`
- [ ] `flutter analyze` → No issues found
- [ ] `flutter test` → 82/82 passed
- [ ] App chạy được trên emulator
- [ ] Đăng nhập / đăng ký thành công
- [ ] UC-05: Active/History tabs, detail + timeline, realtime, cancel
- [ ] UC-06: view/edit profile, upload avatar, address add/edit/delete/set-default
- [ ] Không commit `google-services.json` lên GitHub
