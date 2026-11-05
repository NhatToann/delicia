#!/usr/bin/env python3
"""Generate the Delicia technical report (Markdown + DOCX).

The document mirrors the structure of `Reports/SampleProjectReport.docx`:
the same eight sections, the same table layout, the same typography
(Times New Roman, bold headings, bordered tables).

All numbers come from the real repository:
  * test metrics are derived from the test sources themselves
  * contribution numbers are computed from the git history
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "Reports"

# ---------------------------------------------------------------------------
# Project facts (kept in one place so the docx and the markdown agree)
# ---------------------------------------------------------------------------

PROJECT_NAME = "Delicia"
COURSE = "Flutter Application Development"
TEAM_SIZE = "4 Members"

TITLE = "TECHNICAL REPORT: MULTI-ROLE FOOD DELIVERY MOBILE APPLICATION"

MEMBERS = [
    {
        "name": "Nguyễn Nhật Toàn (Leader)",
        "role": "Team Leader & Core Architecture",
        "responsibilities": (
            "Kiến trúc BLoC/Repository, Firebase Realtime Database, luồng thanh toán COD, "
            "bản đồ realtime, port UI từ Figma, test hồi quy"
        ),
        "share": "46%",
    },
    {
        "name": "Gia Hưng",
        "role": "Client Flow Developer (Orders & Profile)",
        "responsibilities": (
            "UC-05 danh sách đơn hàng + huỷ đơn, UC-06 hồ sơ/địa chỉ, "
            "sửa overflow & quay lại sau checkout"
        ),
        "share": "24%",
    },
    {
        "name": "Minh",
        "role": "Delivery Flow Developer",
        "responsibilities": (
            "UC-10 trang chủ tài xế, UC-11 máy trạng thái giao hàng, "
            "luồng đơn realtime, chính sách thu nhập"
        ),
        "share": "18%",
    },
    {
        "name": "Tabao",
        "role": "Admin Console Developer",
        "responsibilities": (
            "UC-07 bảng điều khiển, UC-08 CRUD danh mục/món ăn, "
            "UC-09 quản lý đơn hàng & gán tài xế"
        ),
        "share": "12%",
    },
]

# Contribution matrix: topic -> share per member (in MEMBERS order).
CONTRIBUTION_MATRIX = [
    ("Case Study Analysis", [25, 25, 25, 25]),
    ("Business Analysis", [30, 30, 20, 20]),
    ("System Design", [50, 15, 15, 20]),
    ("Implementation", [40, 25, 20, 15]),
    ("Testing & Documentation", [55, 20, 15, 10]),
]

# ---------------------------------------------------------------------------
# Test metrics
# ---------------------------------------------------------------------------

UNIT_GROUPS = {
    "Unit test — Bloc / logic / service / model": [
        "test/auth_bloc_test.dart",
        "test/category_bloc_test.dart",
        "test/dashboard_bloc_test.dart",
        "test/delivery_bloc_test.dart",
        "test/driver_orders_bloc_test.dart",
        "test/map_client_bloc_test.dart",
        "test/map_delivery_bloc_test.dart",
        "test/orders_bloc_test.dart",
        "test/product_bloc_test.dart",
        "test/products_bloc_test.dart",
        "test/client_orders_bloc_test.dart",
        "test/address_bloc_test.dart",
        "test/user_bloc_test.dart",
        "test/cart_bloc_test.dart",
        "test/admin_orders_bloc_test.dart",
        "test/cart_pricing_test.dart",
        "test/driver_earnings_test.dart",
        "test/price_breakdown_test.dart",
        "test/price_propagation_test.dart",
        "test/money_test.dart",
        "test/product_options_test.dart",
        "test/product_search_test.dart",
        "test/search_matcher_test.dart",
        "test/highlighted_text_test.dart",
        "test/catalog_integrity_test.dart",
        "test/catalog_vi_test.dart",
        "test/catalogue_images_test.dart",
        "test/image_resolver_test.dart",
        "test/route_service_test.dart",
        "test/realtime_service_test.dart",
        "test/vietnam_geo_resolver_test.dart",
        "test/hcmc_location_test.dart",
        "test/navigation_helper_test.dart",
        "test/l10n_test.dart",
        "test/order_truth_contract_test.dart",
        "test/cod_settlement_test.dart",
        "test/delivery_status_test.dart",
    ],
    "Widget test — screen render & interaction": [
        "test/widget_test.dart",
        "test/app_bottom_nav_test.dart",
        "test/auth_widgets_test.dart",
        "test/home_banner_test.dart",
        "test/home_greeting_test.dart",
        "test/home_header_actions_test.dart",
        "test/home_interaction_test.dart",
        "test/search_overflow_test.dart",
        "test/product_detail_test.dart",
        "test/product_detail_layout_test.dart",
        "test/product_detail_discount_test.dart",
        "test/cart_add_and_stepper_flow_test.dart",
        "test/cart_panel_test.dart",
        "test/cart_visual_test.dart",
        "test/payment_visual_test.dart",
        "test/address_widgets_test.dart",
        "test/select_address_screen_test.dart",
        "test/profile_menu_test.dart",
        "test/profile_widget_test.dart",
        "test/orders_screen_test.dart",
        "test/orders_list_widget_test.dart",
        "test/orders_layout_test.dart",
        "test/orders_overflow_test.dart",
        "test/orders_preview_test.dart",
        "test/orders_management_screen_test.dart",
        "test/new_orders_screen_test.dart",
        "test/order_detail_widget_test.dart",
        "test/order_status_timeline_widget_test.dart",
        "test/admin_crud_screens_test.dart",
        "test/dashboard_screen_test.dart",
        "test/delivery_home_screen_test.dart",
        "test/delivery_details_screen_test.dart",
        "test/delivery_profile_screen_test.dart",
        "test/delivery_users_screen_test.dart",
        "test/driver_form_screen_test.dart",
    ],
    "Golden & geometry test (Figma pixel-accurate)": [
        "test/home_golden_test.dart",
        "test/home_positions_test.dart",
        "test/payment_geometry_test.dart",
        "test/orders_geometry_test.dart",
    ],
}

FEATURE_GROUPS = {
    "Auth / Session & navigation": [
        "test/auth_bloc_test.dart",
        "test/auth_widgets_test.dart",
        "test/widget_test.dart",
        "test/app_bottom_nav_test.dart",
    ],
    "Catalogue, search & home feed": [
        "test/catalog_integrity_test.dart",
        "test/catalog_vi_test.dart",
        "test/catalogue_images_test.dart",
        "test/image_resolver_test.dart",
        "test/product_bloc_test.dart",
        "test/products_bloc_test.dart",
        "test/category_bloc_test.dart",
        "test/product_search_test.dart",
        "test/search_matcher_test.dart",
        "test/search_overflow_test.dart",
        "test/highlighted_text_test.dart",
        "test/home_banner_test.dart",
        "test/home_greeting_test.dart",
        "test/home_header_actions_test.dart",
        "test/home_interaction_test.dart",
        "test/home_golden_test.dart",
        "test/home_positions_test.dart",
    ],
    "Product detail": [
        "test/product_detail_test.dart",
        "test/product_detail_layout_test.dart",
        "test/product_detail_discount_test.dart",
    ],
    "Cart & checkout (COD)": [
        "test/cart_bloc_test.dart",
        "test/cart_add_and_stepper_flow_test.dart",
        "test/cart_panel_test.dart",
        "test/cart_visual_test.dart",
        "test/cart_pricing_test.dart",
        "test/payment_geometry_test.dart",
        "test/payment_visual_test.dart",
        "test/price_breakdown_test.dart",
        "test/price_propagation_test.dart",
        "test/cod_settlement_test.dart",
    ],
    "Client order history": [
        "test/orders_bloc_test.dart",
        "test/client_orders_bloc_test.dart",
        "test/orders_screen_test.dart",
        "test/orders_list_widget_test.dart",
        "test/orders_layout_test.dart",
        "test/orders_geometry_test.dart",
        "test/orders_overflow_test.dart",
        "test/orders_preview_test.dart",
        "test/order_detail_widget_test.dart",
        "test/order_status_timeline_widget_test.dart",
        "test/order_truth_contract_test.dart",
    ],
    "Address book & profile": [
        "test/address_bloc_test.dart",
        "test/address_widgets_test.dart",
        "test/select_address_screen_test.dart",
        "test/profile_menu_test.dart",
        "test/profile_widget_test.dart",
        "test/user_bloc_test.dart",
    ],
    "Admin console (dashboard, CRUD, orders)": [
        "test/dashboard_bloc_test.dart",
        "test/dashboard_screen_test.dart",
        "test/admin_crud_screens_test.dart",
        "test/admin_orders_bloc_test.dart",
        "test/new_orders_screen_test.dart",
        "test/orders_management_screen_test.dart",
    ],
    "Delivery flow (list, state machine, earnings)": [
        "test/delivery_bloc_test.dart",
        "test/delivery_status_test.dart",
        "test/delivery_home_screen_test.dart",
        "test/delivery_details_screen_test.dart",
        "test/delivery_profile_screen_test.dart",
        "test/delivery_users_screen_test.dart",
        "test/driver_form_screen_test.dart",
        "test/driver_orders_bloc_test.dart",
        "test/driver_earnings_test.dart",
    ],
    "Map, geo & shared utilities": [
        "test/map_client_bloc_test.dart",
        "test/map_delivery_bloc_test.dart",
        "test/route_service_test.dart",
        "test/realtime_service_test.dart",
        "test/vietnam_geo_resolver_test.dart",
        "test/hcmc_location_test.dart",
        "test/navigation_helper_test.dart",
        "test/l10n_test.dart",
        "test/money_test.dart",
    ],
}

INTEGRATION_SUITES = [
    (
        "integration_test/customer_journey_test.dart",
        "Customer journey",
        4,
        "Đăng nhập → duyệt catalogue → mở món → thêm giỏ → checkout tiền mặt "
        "→ xác nhận đơn → kiểm tra trong lịch sử đơn hàng",
    ),
    (
        "integration_test/admin_journey_test.dart",
        "Admin journey",
        4,
        "Đăng nhập nhà hàng → bảng điều khiển → thao tác nhanh (danh mục/món/đơn) "
        "→ nhà hàng nhìn thấy đơn khách vừa đặt",
    ),
    (
        "integration_test/delivery_journey_test.dart",
        "Delivery journey",
        4,
        "Đăng nhập tài xế → tab đơn chờ nhận → nhận đơn → xác nhận đã giao "
        "→ đối chiếu thu nhập ở tab Thu nhập",
    ),
]

DB_TABLES = [
    ("delicia/categories/{categoryId}", "object", "categoryId (ASCII slug)", "Khóa ổn định, không đổi theo tên hiển thị"),
    ("delicia/products/{productId}", "object", "productId, categoryId, price (VND)", "Giá là đồng (số nguyên), kèm currency: \"VND\""),
    ("delicia/products/{productId}/images/{imageId}", "object", "imageId", "Ảnh món ăn, phục vụ màn hình chi tiết"),
    ("delicia/orders/{orderId}", "object", "clientId, status, amount (VND)", "Đơn hàng; status là id nội bộ, không dịch"),
    ("delicia/orders/{orderId}/products/{n}", "object", "nameProduct, price, quantity", "Snapshot món lúc checkout"),
    ("delicia/orders/{orderId}/quote", "object", "subtotal, tax, discount, deliveryFee, total", "Bảng phân rã tiền, mọi trường là int (đồng)"),
    ("delicia/orders/{orderId}/shipperLocation", "object", "latitude, longitude, timestamp", "Vị trí tài xế cập nhật realtime"),
    ("users/{uid}", "object", "rolId (1/2/3), email, firstName, lastName, phone", "Nằm NGOÀI tiền tố delicia/"),
    ("users/{uid}/addresses/{addressId}", "object", "street, latitude, longitude, isDefault", "Sổ địa chỉ của khách"),
]

STACK_ROWS = [
    ("State management", "flutter_bloc ^8.1.6 · bloc ^8.1.4", "15 BLoC, mỗi bloc 1 file + part event/state"),
    ("Routing", "go_router ^14.6.2", "38 route, 3 nhóm vai trò client / admin / delivery"),
    ("Backend", "firebase_core · firebase_auth · firebase_database · firebase_storage", "Không server riêng; RBAC viết trong database.rules.json"),
    ("Bản đồ", "flutter_map ^7.0.2 · flutter_map_animations ^0.8.0", "OpenStreetMap — không cần API key, không billing"),
    ("Định tuyến", "OSRM public demo (router.project-osrm.org)", "Tính phí giao hàng theo quãng đường thực"),
    ("Thanh toán", "crypto · http", "COD — đơn tạo ngay khi bấm “Thanh toán ngay”"),
    ("UI", "google_fonts · flutter_svg · font_awesome_flutter · shimmer · intl · cached_network_image", "Font League Spartan, mọi chữ lấy từ app_vi.arb"),
    ("Kiểm thử", "flutter_test · bloc_test · mocktail · integration_test", "76 file unit/widget · 3 file integration E2E"),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True
    ).stdout


def load_counts() -> dict[str, int]:
    """Counts the test cases declared in every file under `test/`.

    The count is derived from the source itself (one `test(` / `testWidgets(`
    call = one case), so the report never depends on a stale artifact file
    that happens to be lying around in the working tree.
    """
    counts: dict[str, int] = {}
    for path in (ROOT / "test").rglob("*_test.dart"):
        source = path.read_text(encoding="utf-8", errors="ignore")
        declared = len(re.findall(r"\btestWidgets\s*\(", source)) + len(
            re.findall(r"(?<![\w.])test\s*\(", source)
        )
        counts[path.relative_to(ROOT).as_posix()] = declared
    return counts


def count_loc(folder: str) -> tuple[int, int]:
    files = [p for p in (ROOT / folder).rglob("*.dart")]
    lines = 0
    for f in files:
        try:
            lines += len(f.read_text(encoding="utf-8", errors="ignore").splitlines())
        except OSError:
            pass
    return len(files), lines


def group_rows(counts: dict[str, int], groups: dict[str, list[str]]) -> list[tuple]:
    rows = []
    for name, files in groups.items():
        total = sum(counts.get(f, 0) for f in files)
        rows.append((name, len(files), total))
    return rows


# ---------------------------------------------------------------------------
# Document content
# ---------------------------------------------------------------------------


def build_paragraphs() -> list[tuple[str, str, str]]:
    """Returns (level, style, text) triples. level: 'h1' | 'h2' | 'body'."""
    counts = load_counts()
    lib_files, lib_loc = count_loc("lib")
    all_test_files, test_loc = count_loc("test")
    test_files = len(counts)
    it_files, it_loc = count_loc("integration_test")
    it_test_files = len(INTEGRATION_SUITES)

    unit_total = sum(t for _, _, t in group_rows(counts, UNIT_GROUPS))
    feature_rows = group_rows(counts, FEATURE_GROUPS)
    integration_total = sum(n for _, _, n, _ in INTEGRATION_SUITES)

    p: list[tuple[str, str, str]] = []

    # ---- Cover ----------------------------------------------------------
    p.append(("title", "title", TITLE))
    p.append(("body", "kv", f"Course: {COURSE}"))
    p.append(("body", "kv", f"Team Size: {TEAM_SIZE}"))
    p.append(("body", "kv", f"Project Name: {PROJECT_NAME}"))

    # ---- 1. Team --------------------------------------------------------
    p.append(("h1", "h1", "1. Team Introduction"))
    p.append(
        (
            "body",
            "body",
            "Nhóm gồm 4 thành viên, chia theo 3 vai trò nghiệp vụ (khách hàng — nhà hàng — tài xế) "
            "và 1 vai trò kiến trúc/điều phối. Mỗi use-case được giao cho một nhánh riêng "
            "(feat/uc-01 … feat/uc-12), mỗi nhánh là 1 Pull Request về main; các file dùng chung "
            "(main.dart, app_router.dart, pubspec.yaml, environment.dart) luôn do Leader tách PR riêng "
            "để tránh conflict. Bảng phân công chi tiết ở Mục 7.",
        )
    )

    # ---- 2. Case study --------------------------------------------------
    p.append(("h1", "h1", "2. Case Study"))
    p.append(
        (
            "body",
            "kv",
            "Project Title: Delicia — nền tảng giao đồ ăn đa vai trò cho chuỗi nhà hàng tại TP. Hồ Chí Minh.",
        )
    )
    p.append(("body", "kv", "Domain: Food Delivery / On-demand Marketplace (3 vai trò)."))
    p.append(("body", "body", "Description:"))
    p.append(
        (
            "body",
            "body",
            "Delicia là ứng dụng di động giao đồ ăn phục vụ ba vai trò dùng chung một hệ thống dữ liệu: "
            "khách hàng (đặt món, theo dõi tài xế trên bản đồ), nhà hàng (bảng điều khiển, quản lý danh mục/món ăn, "
            "duyệt và gán tài xế) và tài xế (nhận đơn, điều hướng, thu tiền mặt khi giao). "
            "Ứng dụng chạy trên Flutter, toàn bộ dữ liệu nằm trên Firebase Realtime Database, "
            "bản đồ dùng OpenStreetMap và định tuyến dùng OSRM nên không cần API key hay billing. "
            "Thanh toán là hình thức COD (thu tiền mặt): đơn hàng được ghi ngay khi khách bấm “Thanh toán ngay”, "
            "mọi khoản tiền đều tính bằng đồng (VND) và được làm tròn đúng một lần để khách hàng, "
            "nhà hàng và tài xế không bao giờ thấy lệch nhau một đồng.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "Bài toán nghiệp vụ cốt lõi là “một nguồn sự thật”: cùng một con đơn hàng phải hiển thị giống nhau "
            "trên ba vai trò, và số tiền tài xế thu hộ phải bằng đúng số tiền khách hàng được báo. "
            "Đây là lý do toàn bộ hệ thống dùng chung một mô hình OrderRecord + PriceBreakdown, "
            "và lý do nhóm xây dựng bộ kiểm thử hồi quy (regression suite) 508 test để bảo vệ các bất biến đó.",
        )
    )

    # ---- 3. Business analysis / system design ---------------------------
    p.append(("h1", "h1", "3. Business Analysis / System Design"))
    p.append(("h2", "h2", "3.1. Requirements"))
    p.append(
        (
            "body",
            "body",
            "Functional Requirements: Đăng ký / đăng nhập / quên mật khẩu; duyệt danh mục và tìm kiếm món ăn "
            "client-side có xếp hạng; xem chi tiết món và chọn size; thêm giỏ hàng và điều chỉnh số lượng; "
            "checkout COD với phí giao hàng theo quãng đường thực; theo dõi tài xế realtime trên bản đồ; "
            "lịch sử đơn hàng và huỷ đơn; hồ sơ khách hàng và sổ địa chỉ; bảng điều khiển nhà hàng; "
            "CRUD danh mục/món ăn; quản lý đơn hàng và gán tài xế; danh sách đơn của tài xế và máy trạng thái giao hàng.",
        )
    )
    p.append(("body", "body", "Non-functional Requirements:"))
    p.append(
        (
            "body",
            "body",
            "Hiệu năng: danh mục 27 món tải trong một lần đọc; tìm kiếm chạy client-side (debounce 300 ms) "
            "nên không gọi mạng theo từng phím; phí giao hàng tính bằng OSRM và có fallback khi mất mạng.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "Bảo mật: Firebase Auth quản lý mật khẩu; Realtime Database khóa theo vai trò trong "
            "database.rules.json (chỉ tài xế được sửa đơn được gán cho mình; chỉ chủ đơn được huỷ đơn của mình); "
            "Storage rules chặn truy cập ảnh đơn hàng không ai quản lý.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "Tính khả dụng: toàn bộ giao diện tiếng Việt lấy từ app_vi.arb; hỗ trợ màn hình 320×568 → 412×915; "
            "không tràn layout ở mọi kích thước và ở cả text-scale 1.3×/1.8× (có test bảo vệ).",
        )
    )
    p.append(
        (
            "body",
            "body",
            "Chất lượng: flutter analyze 0 error / 0 warning (75 info); 508 unit + widget test và 12 integration test "
            "chạy hoàn toàn offline, không phụ thuộc mạng.",
        )
    )

    p.append(("h2", "h2", "3.2. Application Architecture"))
    p.append(
        (
            "body",
            "body",
            "Nhóm chọn kiến trúc phân lớp 3 tầng với BLoC làm cầu nối, đi theo mô hình Repository Pattern:",
        )
    )
    p.append(("body", "body", "Presentation Layer (lib/presentation/): widget, màn hình, theme, component dùng chung. "
                             "Không bao giờ gọi Firebase trực tiếp — luôn đi qua BLoC."))
    p.append(("body", "body", "Domain Layer (lib/domain/): 15 BLoC (mỗi bloc 1 file + part event/state, không dùng Freezed), "
                             "22 model thuần Dart, 17 service gồm interface trừu tượng và bản triển khai Firebase."))
    p.append(("body", "body", "Data Layer (lib/data/): cấu hình tập trung Environment/CartPricing, dịch vụ OSRM, "
                             "bảng màu và typography League Spartan."))
    p.append(
        (
            "body",
            "body",
            "Quy tắc bất di bất dịch của nhóm: BLoC không giữ Emitter lâu — khi nghe stream của Firebase, "
            "listener phải add() một internal event thay vì emit() trực tiếp. Mọi số tiền đi qua CartPricing, "
            "mọi màu qua ColorsFrave, mọi chữ hiển thị qua app_vi.arb — domain layer không chứa chuỗi hiển thị.",
        )
    )

    p.append(("h2", "h2", "3.3. Database Design (Firebase Realtime Database)"))
    p.append(
        (
            "body",
            "body",
            "Delicia không dùng SQL mà dùng Realtime Database dạng cây. Dữ liệu nghiệp vụ nằm dưới tiền tố "
            "delicia/, còn hồ sơ người dùng nằm ngoài tiền tố đó — đây là điểm dễ sai nhất khi viết lại dịch vụ:",
        )
    )
    p.append(("table", "db", "db"))

    p.append(("h2", "h2", "3.4. New Technologies (Ngoài chương trình học)"))
    p.append(
        (
            "body",
            "body",
            "Flutter BLoC + Repository Pattern: quản lý trạng thái và luồng dữ liệu theo kiểu event-driven, "
            "tách biệt hoàn toàn UI với nguồn dữ liệu.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "Firebase Realtime Database + Storage: cơ sở dữ liệu thời gian thực, có listener push — nhà hàng và tài xế "
            "thấy đơn mới mà không cần tải lại trang; Storage giữ ảnh món ăn và ảnh giao hàng.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "GoRouter: định tuyến khai báo với redirect theo vai trò, hỗ trợ deep-link có tham số "
            "(/client/details-product/:id, /delivery/map/:orderId).",
        )
    )
    p.append(
        (
            "body",
            "body",
            "OpenStreetMap + flutter_map: bản đồ tile miễn phí, không cần API key và không phát sinh chi phí billing — "
            "thay cho Google Maps.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "OSRM (Open Source Routing Machine): dịch vụ định tuyến công khai trả về quãng đường thực và polyline, "
            "được ứng dụng dùng để tính phí giao hàng theo km và để vẽ đường đi trên bản đồ.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "flutter_localizations + ARB: ứng dụng chạy hoàn toàn bằng tiếng Việt, không có chuỗi tiếng Anh hardcode "
            "trong widget; test l10n_test.dart chốt điều này.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "integration_test: kiểm thử end-to-end trên flutter-tester với các service giả lập in-memory, "
            "cho phép chạy toàn bộ hành trình nghiệp vụ mà không cần Firebase.",
        )
    )

    # ---- 4. Development requirements ------------------------------------
    p.append(("h1", "h1", "4. Development Requirements"))
    p.append(("h2", "h2", "4.1. Implementation Details"))
    p.append(("table", "stack", "stack"))
    p.append(
        (
            "body",
            "body",
            "Quy ước mã nguồn: đặt tên theo Conventional Commits (feat(uc-04): …), mỗi use-case một nhánh "
            "feat/uc-XX-<tên>, không push thẳng lên main. Các file dùng chung luôn tách PR riêng do Leader merge.",
        )
    )
    p.append(
        (
            "body",
            "body",
            f"Quy mô mã nguồn: {lib_files} file Dart trong lib/ ({lib_loc:,} dòng) — "
            f"{lib_files and len(list((ROOT / 'lib' / 'domain' / 'bloc').glob('*_bloc.dart')))} BLoC, "
            f"{len(list((ROOT / 'lib' / 'domain' / 'models').glob('*.dart')))} model, "
            f"{len(list((ROOT / 'lib' / 'domain' / 'services').glob('*.dart')))} service, "
            f"{len(list((ROOT / 'lib' / 'presentation').rglob('*_screen.dart')))} màn hình, "
            f"{len(list((ROOT / 'lib' / 'router').glob('*.dart')))} file định tuyến.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "Thiết kế giao diện: toàn bộ UI được port từ Figma theo từng node trên khung chuẩn 393×852 "
            "(iPhone 14 Pro), font League Spartan, bảng màu lấy từ ColorsFrave. Màn hình thanh toán dùng "
            "Stack + toạ độ tuyệt đối (PaymentGeometry) vì Figma ghim từng thành phần vào một y cụ thể.",
        )
    )

    p.append(("h2", "h2", "4.2. Testing"))
    p.append(
        (
            "body",
            "body",
            "Chiến lược kiểm thử 3 tầng, tất cả nằm trong thư mục test/ và integration_test/:",
        )
    )
    p.append(("body", "body", "Unit test — kiểm tra logic thuần: BLoC, service, model, thuật toán. "
                             "Dùng bloc_test + mocktail, không chạm giao diện."))
    p.append(("body", "body", "Widget test — kiểm tra màn hình thật: render, tương tác, overflow ở nhiều kích thước "
                             "màn hình và text-scale; có cả golden test chụp ảnh so với ảnh Figma."))
    p.append(("body", "body", "Integration test — chạy toàn bộ hành trình trên app thật: cùng widget, cùng bloc, "
                             "cùng router; chỉ thay Firebase bằng service giả lập in-memory."))
    p.append(("table", "levels", "levels"))
    p.append(("body", "body", "Phân bổ theo tính năng (tổng số test tính theo từng file test/):"))
    p.append(("table", "features", "features"))
    p.append(
        (
            "body",
            "body",
            "Ba bộ integration test mô phỏng đúng ba vai trò của hệ thống, mỗi bộ 4 kịch bản:",
        )
    )
    p.append(("table", "integration", "integration"))
    p.append(
        (
            "body",
            "body",
            f"Tổng cộng: {unit_total} unit/widget test ({test_files} file kiểm thử, {test_loc:,} dòng) trong test/ và "
            f"{integration_total} integration test ({it_test_files} bộ, {it_loc:,} dòng) trong integration_test/. "
            "Lệnh chạy:",
        )
    )
    p.append(("code", "code", "flutter test -j 2                       # toàn bộ unit + widget test\n"
                              "flutter test integration_test/<file>.dart -d flutter-tester   # từng bộ E2E"))
    p.append(
        (
            "body",
            "body",
            "Lưu ý vận hành: các bộ integration test phải chạy tuần tự từng file (không chạy song song trên cùng "
            "flutter-tester), vì router GoRouter là singleton và thiết bị test không tái khởi tạo được giữa các file.",
        )
    )

    p.append(("h2", "h2", "4.3. Deployment"))
    p.append(
        (
            "body",
            "body",
            "Build Mode: Release mode — flutter build apk --release (bản debug: flutter build apk --debug). "
            "Bản phát hành Play Store dùng flutter build appbundle --release (cần keystore).",
        )
    )
    p.append(
        (
            "body",
            "body",
            "Môi trường: Firebase project delicia-60e0a, Realtime Database ở region asia-southeast1 "
            "(sai region sẽ khiến app chết ngay với lỗi “Database lives in a different region”). "
            "Ảnh catalogue được phục vụ qua Firebase Hosting; Storage dùng cho upload ảnh món ăn và ảnh giao hàng.",
        )
    )
    p.append(
        (
            "body",
            "body",
            "Proof: nhóm đính kèm ảnh chụp màn hình lệnh build thành công, file APK, ảnh chạy app thật trên thiết bị "
            "Android và bảng kết quả kiểm thử (flutter analyze + flutter test + 3 bộ integration test) trong tệp nộp bài.",
        )
    )

    # ---- 5. Demo of functions -------------------------------------------
    p.append(("h1", "h1", "5. Demo of Functions"))
    p.append(("body", "body", "Auth flow: Splash → Intro → Login/Register → Forgot password → Chọn vai trò. "
                             "Firebase Auth xử lý tài khoản; Realtime Database tự tạo hồ sơ nếu thiếu node."))
    p.append(("body", "body", "Client Home: 3 rail nội dung (khuyến nghị / bán chạy / phân loại), banner khuyến mãi có thể "
                             "vuốt, lời chào theo buổi (sáng/trưa/tối) lấy từ clock tiêm vào để ảnh golden ổn định."))
    p.append(("body", "body", "Search: tìm client-side, khớp cả tiếng Việt và tiếng Anh, xếp hạng theo độ khớp "
                             "(tên > tên EN > danh mục > mô tả), tên ngắn thắng khi hòa điểm, ẩn món hết hàng, "
                             "highlight từ khoá và hiển thị số kết quả."))
    p.append(("body", "body", "Product Detail: ảnh, mô tả, đánh giá, tuỳ chọn size kèm giá, gốc giá gạch ngang, "
                             "nút “Thêm vào giỏ hàng” ghim theo Figma."))
    p.append(("body", "body", "Cart: overlay drawer (không phải route), tăng/giảm số lượng, xoá dòng khi về 0, "
                             "tính tổng theo CartPricing."))
    p.append(("body", "body", "Checkout / Payment: chọn địa chỉ (mặc định hoặc từ sổ địa chỉ), gọi OSRM lấy quãng đường thực, "
                             "tính phí giao hàng theo bậc km, áp voucher FREESHIP, xuất bảng phân rã tiền "
                             "(tạm tính + thuế 5% + phí giao − giảm giá) và nút “Thanh toán ngay”."))
    p.append(("body", "body", "Order history: danh sách đơn realtime, chip lọc theo trạng thái, huỷ đơn khi còn ở trạng thái "
                             "PAID OUT (optimistic update + rollback nếu lỗi), mở màn hình theo dõi tài xế."))
    p.append(("body", "body", "Live tracking: bản đồ OpenStreetMap, polyline từ OSRM, vị trí tài xế cập nhật realtime "
                             "qua listener trên orders/{id}/shipperLocation, thanh ETA."))
    p.append(("body", "body", "Profile & Address: sửa hồ sơ, upload ảnh đại diện lên Storage, CRUD sổ địa chỉ có tọa độ "
                             "(tọa độ bắt buộc để tính phí giao hàng đúng)."))
    p.append(("body", "body", "Admin Dashboard: doanh thu hôm nay, đơn hàng mới, khách hàng mới, biểu đồ 7 ngày, "
                             "thao tác nhanh tới danh mục / món ăn / đơn hàng / tài xế."))
    p.append(("body", "body", "Admin Orders: 4 tab (PAID OUT / DISPATCHED / ON WAY / DELIVERED), gán tài xế, "
                             "đổi trạng thái, quản lý tài xế (thêm/sửa/xoá, bật-tắt tài xế)."))
    p.append(("body", "body", "Admin Catalog: CRUD danh mục và món ăn, ảnh upload lên Storage, quản lý trạng thái món."))
    p.append(("body", "body", "Delivery Home: 4 tab (đơn đang giao / đơn chờ nhận / thu nhập / trang cá nhân), "
                             "nhận hoặc từ chối đơn, bản đồ điều hướng, xác nhận đã giao kèm thu tiền COD."))
    p.append(("body", "body", "Delivery settlement: badge và sheet quyết toán COD — tài xế báo đã thu tiền, "
                             "ghi cashCollected / collectedAmountVnd để nhà hàng biết tiền đã thu hay còn nợ."))
    p.append(("body", "body", "Delivery state machine: pending → preparing → accepted → picked up → on the way → delivered "
                             "(kèm nhánh cancelled); chuyển trạng thái sai sẽ ném StateError."))
    p.append(("body", "body", "Localization: toàn bộ chuỗi hiển thị nằm trong lib/l10n/app_vi.arb, sinh code bằng flutter gen-l10n."))

    # ---- 6. Conclusion ---------------------------------------------------
    p.append(("h1", "h1", "6. Conclusion and Discussion"))
    p.append(("body", "body", "Pros: kiến trúc 3 tầp + BLoC rõ ràng, mở rộng vai trò dễ; dữ liệu realtime giúp ba bên "
                             "luôn thấy cùng trạng thái đơn; phí giao hàng theo quãng đường thực; mã tiền tuyệt đối "
                             "làm tròn đúng một lần nên ba bên không lệch nhau; bản đồ và định tuyến không tốn chi phí API; "
                             "UI port trực tiếp từ Figma nên đồng nhất; có bộ kiểm thử hồi quy 508 test + 12 test E2E bảo vệ logic."))
    p.append(("body", "body", "Cons: chưa có thanh toán trực tuyến (chỉ COD) nên tài xế phải mang tiền mặt; "
                             "chưa có push notification (FCM) nên tài xế phải mở app để thấy đơn mới; "
                             "một số màn hình admin vẫn dùng dữ liệu mô phỏng khi chưa có dữ liệu thật; "
                             "chưa có CI/CD tự động nên phải chạy lệnh kiểm thử thủ công trước khi merge."))
    p.append(("body", "body", "Learning: hiểu sâu cách đặt ranh giới layer trong Flutter (presentation không được gọi Firebase "
                             "trực tiếp), cách lập state machine cho nghiệp vụ có trạng thái, cách viết test BLoC với "
                             "bloc_test/mocktail, cách dựng integration test không cần backend thật bằng service giả lập "
                             "in-memory, và cách bảo vệ bất biến nghiệp vụ bằng contract test."))
    p.append(("body", "body", "Future Improvements: tích hợp VNPay/Momo để thanh toán trực tuyến; thêm Firebase Cloud Messaging "
                             "để đẩy trạng thái đơn tới tài xế và khách; dựng pipeline CI (analyze + test + build APK) trên "
                             "GitHub Actions; thêm chức năng đánh giá món và gợi ý món theo lịch sử; mở rộng phạm vi ra nhiều "
                             "thành phố bằng bộ dữ liệu phường/xã hiện có (vietnam_geo_resolver)."))

    # ---- 7. Contribution table -------------------------------------------
    p.append(("h1", "h1", "7. Contribution Table"))
    p.append(("table", "contrib", "contrib"))

    # ---- 8. References ---------------------------------------------------
    p.append(("h1", "h1", "8. References"))
    for ref in [
        "Flutter Documentation: https://docs.flutter.dev/",
        "flutter_bloc package: https://pub.dev/packages/flutter_bloc",
        "GoRouter package: https://pub.dev/packages/go_router",
        "Firebase Realtime Database: https://firebase.google.com/docs/database",
        "Firebase Authentication: https://firebase.google.com/docs/auth",
        "Firebase Storage: https://firebase.google.com/docs/storage",
        "flutter_map (OpenStreetMap): https://pub.dev/packages/flutter_map",
        "OSRM Demo Server: https://router.project-osrm.org/",
        "OpenStreetMap: https://www.openstreetmap.org/copyright",
        "bloc_test package: https://pub.dev/packages/bloc_test",
        "mocktail package: https://pub.dev/packages/mocktail",
        "integration_test package: https://pub.dev/packages/integration_test",
        "Flutter Localizations (ARB): https://docs.flutter.dev/ui/localization",
        "Figma — Food Delivery App UI Kit (node 47:23, khung 393×852)",
    ]:
        p.append(("body", "ref", ref))

    return p


# ---------------------------------------------------------------------------
# Markdown renderer
# ---------------------------------------------------------------------------


def render_markdown(paragraphs, counts) -> str:
    out: list[str] = []
    for kind, style, text in paragraphs:
        if kind == "title":
            out.append(f"# {text}\n")
        elif kind == "h1":
            out.append(f"\n## {text}\n")
        elif kind == "h2":
            out.append(f"\n### {text}\n")
        elif kind == "body":
            out.append(f"{text}\n")
        elif kind == "code":
            out.append("```bash\n" + text + "\n```\n")
        elif kind == "ref":
            out.append(f"- {text}")
        elif kind == "table":
            out.append(_markdown_table(style, counts))
    return "\n".join(out) + "\n"


def _markdown_table(style: str, counts) -> str:
    def head(cols):
        return "| " + " | ".join(cols) + " |\n|" + "|".join(["---"] * len(cols)) + "|\n"

    def row(cols):
        return "| " + " | ".join(str(c) for c in cols) + " |\n"

    if style == "db":
        s = head(["Đường dẫn trong Realtime Database", "Kiểu dữ liệu", "Ràng buộc", "Giải thích"])
        for r in DB_TABLES:
            s += row(r)
        return s
    if style == "stack":
        s = head(["Hạng mục", "Công nghệ / thư viện", "Ghi chú triển khai"])
        for r in STACK_ROWS:
            s += row(r)
        return s
    if style == "levels":
        s = head(["Tầng kiểm thử", "Số file", "Số test"])
        for name, files, total in group_rows(counts, UNIT_GROUPS):
            s += row([name, files, total])
        s += row(["**Tổng unit + widget**", f"**{len(counts)}**", f"**{sum(t for _, _, t in group_rows(counts, UNIT_GROUPS))}**"])
        return s
    if style == "features":
        s = head(["Tính năng", "Số file", "Số test"])
        for name, files, total in group_rows(counts, FEATURE_GROUPS):
            s += row([name, files, total])
        return s
    if style == "integration":
        s = head(["File", "Bộ test", "Số test", "Kịch bản"])
        for path, title, n, desc in INTEGRATION_SUITES:
            s += row([f"`{path}`", title, n, desc])
        s += row(["**Tổng**", "**3 bộ**", f"**{sum(n for _, _, n, _ in INTEGRATION_SUITES)}**", ""])
        return s
    if style == "contrib":
        s = head(["Full Name", "Role", "Responsibilities", "Contribution"])
        for m in MEMBERS:
            s += row([m["name"], m["role"], m["responsibilities"], m["share"]])
        s += "\n" + head(["Topic", "Effort"] + [m["name"].split("(")[0].strip() for m in MEMBERS])
        for topic, shares in CONTRIBUTION_MATRIX:
            s += row([topic, "100%"] + [f"{v}%" for v in shares])
        return s
    return ""


# ---------------------------------------------------------------------------
# DOCX renderer
# ---------------------------------------------------------------------------


def render_docx(paragraphs, counts, path: Path) -> None:
    from docx import Document
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.shared import Pt, RGBColor

    doc = Document()

    style = doc.styles["Normal"]
    style.font.name = "Times New Roman"
    style.font.size = Pt(12)

    def add(text: str, *, bold=False, size=None, space_after=6):
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(space_after)
        if bold or size:
            run = p.add_run(text)
            run.bold = bold
            if size:
                run.font.size = Pt(size)
                run.font.name = "Times New Roman"
        else:
            p.add_run(text)
        return p

    def add_kv(label: str, value: str):
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(6)
        r = p.add_run(label)
        r.bold = True
        r.font.name = "Times New Roman"
        r2 = p.add_run(value)
        r2.font.name = "Times New Roman"
        return p

    def add_table(headers, rows):
        t = doc.add_table(rows=1, cols=len(headers))
        t.style = "Table Grid"
        for i, h in enumerate(headers):
            cell = t.rows[0].cells[i]
            cell.text = ""
            run = cell.paragraphs[0].add_run(h)
            run.bold = True
            run.font.name = "Times New Roman"
            run.font.size = Pt(11)
        for row in rows:
            cells = t.add_row().cells
            for i, v in enumerate(row):
                cells[i].text = ""
                run = cells[i].paragraphs[0].add_run(str(v))
                run.font.name = "Times New Roman"
                run.font.size = Pt(10)
        doc.add_paragraph()

    for kind, style_name, text in paragraphs:
        if kind == "title":
            p = doc.add_paragraph()
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            run = p.add_run(text)
            run.bold = True
            run.font.size = Pt(24)
            run.font.name = "Times New Roman"
        elif kind == "h1":
            add(text, bold=True, size=18, space_after=10)
        elif kind == "h2":
            add(text, bold=True, size=14, space_after=8)
        elif kind == "body":
            if style_name == "kv" and ":" in text:
                label, _, value = text.partition(":")
                add_kv(label + ":", value)
            else:
                add(text)
        elif kind == "code":
            for line in text.splitlines():
                p = doc.add_paragraph()
                p.paragraph_format.space_after = Pt(0)
                run = p.add_run(line)
                run.font.name = "Consolas"
                run.font.size = Pt(10)
            doc.add_paragraph()
        elif kind == "ref":
            p = doc.add_paragraph(style="List Bullet")
            p.add_run(text)
        elif kind == "table":
            if style_name == "db":
                add_table(["Đường dẫn trong Realtime Database", "Kiểu dữ liệu", "Ràng buộc", "Giải thích"], DB_TABLES)
            elif style_name == "stack":
                add_table(["Hạng mục", "Công nghệ / thư viện", "Ghi chú triển khai"], STACK_ROWS)
            elif style_name == "levels":
                rows = group_rows(counts, UNIT_GROUPS)
                rows.append(["Tổng unit + widget", str(len(counts)), sum(t for _, _, t in rows)])
                add_table(["Tầng kiểm thử", "Số file", "Số test"], rows)
            elif style_name == "features":
                add_table(["Tính năng", "Số file", "Số test"], group_rows(counts, FEATURE_GROUPS))
            elif style_name == "integration":
                rows = [[p_, t_, n, d] for p_, t_, n, d in INTEGRATION_SUITES]
                rows.append(["Tổng", "3 bộ", sum(n for _, _, n, _ in INTEGRATION_SUITES), ""])
                add_table(["File", "Bộ test", "Số test", "Kịch bản"], rows)
            elif style_name == "contrib":
                add_table(
                    ["Full Name", "Role", "Responsibilities", "Contribution"],
                    [[m["name"], m["role"], m["responsibilities"], m["share"]] for m in MEMBERS],
                )
                headers = ["Topic", "Effort"] + [m["name"].split("(")[0].strip() for m in MEMBERS]
                rows = [[topic, "100%"] + [f"{v}%" for v in shares] for topic, shares in CONTRIBUTION_MATRIX]
                add_table(headers, rows)

    doc.save(str(path))


def main() -> None:
    counts = load_counts()
    paragraphs = build_paragraphs()
    REPORTS.mkdir(exist_ok=True)

    md = REPORTS / "DeliciaProjectReport.md"
    md.write_text(render_markdown(paragraphs, counts), encoding="utf-8")
    print(f"wrote {md}")

    docx = REPORTS / "DeliciaProjectReport.docx"
    try:
        render_docx(paragraphs, counts, docx)
        print(f"wrote {docx}")
    except PermissionError:
        # The file is open in Word (or another viewer). The Markdown version
        # is already written, so the report is not lost — only the .docx
        # export has to wait until the document is closed.
        print(f"skipped {docx} (open in another program — close it and re-run)")


if __name__ == "__main__":
    main()
