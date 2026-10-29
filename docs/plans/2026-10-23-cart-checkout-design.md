# Cart & Checkout — Design Spec (Figma 4.3-A / 4.3-B / 4.3-C)

**Date:** 2026-10-23
**Scope:** UC-04 Cart + Checkout refactor
**Figma file:** `tVh0aA6EL18IotmAMXwO3p` ("Food Delivery App UI Kit")

| Screen | Node | Local reference |
|---|---|---|
| 4.3 - A - Cart (empty) | `202:2213` | `assets/.../4.3 - A - Cart.png` |
| 4.3 - B - Cart (populated) | `202:1358` | `assets/.../4.3 - B - Cart.png` |
| 4.3 - C - Checkout | `199:1715` | `assets/.../4.3 - C - Checkout.png` |

---

## 1. Decisions taken

| Question | Decision |
|---|---|
| Presentation | **Slide panel overlay** over Home (Figma 1:1), reusing the existing `ProfileMenuOverlay` pattern. The old `/client/cart` full-screen route is kept but re-skinned to the Figma panel look. |
| Scope | Cart (4.3-A + 4.3-B) **+** Checkout refactor (4.3-C). |
| Pricing source | **Central config** — new `CartPricing` in `lib/data/env/environment.dart`. Both Cart and Checkout read from it. No hardcoded money anywhere. |

---

## 2. Architecture

```
lib/
├── data/env/environment.dart          # + CartPricing (single source of truth for money)
├── domain/bloc/cart/                  # existing — unchanged logic
├── presentation/client/cart/
│   ├── cart_screen.dart               # rewritten → Figma slide panel
│   └── widgets/
│       ├── cart_panel.dart             # NEW — panel shell (empty + populated)
│       ├── cart_item_row.dart          # NEW — one product row
│       ├── cart_quantity_stepper.dart  # NEW −/qty/+ control
│       ├── cart_summary.dart           # NEW — Subtotal/Tax/Delivery/Total
│       └── cart_empty_state.dart       # NEW — 4.3-A
├── presentation/client/checkout/
│   ├── checkout_screen.dart            # rewritten → Figma 4.3-C
│   └── widgets/ (existing selectors kept)
└── presentation/client/home/home_screen.dart  # `_openCart()` now opens the panel
```

**Why a panel, not a route:** Figma draws Cart as a drawer over the Home screen
(panel `#E95322`, 330 px wide, sliding in from the right edge, with the Home
screen dimmed by a `#FE4A0C @ 31%` scrim on the left 174 px). The project already
ships this exact pattern in `presentation/client/home/widgets/profile_menu.dart`
(`ProfileMenuOverlay`), so Cart reuses that vocabulary instead of inventing one.

---

## 3. Geometry (393 x 852 frame)

### Panel
| Property | Value |
|---|---|
| Fill | `#E95322` (`ColorsFrave.navOrange`) |
| Width | 330 px (≈ 84 % of screen) |
| Left corner radius | 80 px (top-left + bottom-left only, flush to right edge) |
| Backdrop | `#FE4A0C` @ 31 % over the left strip |
| Shadow | `dy 4, blur 2, black @ 25 %` (from `cart_panel_bg.svg`) |

### Header (4.3-A / 4.3-B)
| Element | Geometry |
|---|---|
| Title "Cart" | League Spartan **Bold 24**, `#F8F8F8`, y76 |
| Cart icon (basket in white rounded square) | 40 px, x135 y66, radius 20, bg `#F8F8F8` |
| Subtitle (B only) | League Spartan **Medium 20**, `#F8F8F8`, y165 — *"You have 2 items in the cart"* |
| Empty subtitle (A) | League Spartan **Medium 20**, `#F8F8F8`, y165 — *"Your cart is empty"* |

### Product row (4.3-B)
| Element | Geometry |
|---|---|
| Thumbnail | 99 x 99, radius 20, x? |
| Name | League Spartan **Medium 15**, `#F8F8F8`, letter-spacing 0.45 |
| Date / time | League Spartan **Medium 13**, white — `29/11/24` + `15:00` |
| Line price | League Spartan **Light 14**, `#F8F8F8` — `$20.00` |
| Quantity stepper | pill, height 16, width 47, radius 10; `−` left, `+` right, count centered at 13 px |

### Summary block (4.3-B / 4.3-C)
| Label | Value |
|---|---|
| Subtotal | product total |
| Tax and Fees | `subtotal × taxRate` |
| Delivery | flat `deliveryFee` |
| Total | `subtotal + tax + delivery` |

Labels: League Spartan **Medium 20**, `#F8F8F8` (panel) / `#391713` (checkout page).
Values: League Spartan **Medium 20**, `#F8F8F8` (panel) / `#E95322` (checkout page).

### Buttons
| Button | Style |
|---|---|
| "Checkout" (panel) | bg `#F5CB58`, text `#E95322`, League Spartan **Medium 24**, radius 30, full-width |
| "Place Order" (checkout) | bg `#FFDECF`, text `#E95322`, League Spartan **Regular 23**, radius 38, pill, centred |

### Empty state (4.3-A)
| Element | Geometry |
|---|---|
| Big basket icon in orange circle | 184 x 184, radius 51.5, x135 y308 |
| Headline | *"Want to add something?"* — League Spartan **Bold 24**, white |
| Body | *"Your cart is empty"* — League Spartan **Medium 20**, `#F8F8F8` |
| CTA | Yellow pill → `/client/home` |

---

## 4. Money model — no hardcoded prices

New `CartPricing` in `lib/data/env/environment.dart`:

```dart
class CartPricing {
  static const double deliveryFee = 2.5;
  static const double taxRate = 0.05;
  static double taxOf(double subtotal) => subtotal * taxRate;
  static double totalOf(double subtotal) => subtotal + taxOf(subtotal) + deliveryFee;
}
```

- `CartBloc.state.total` stays the **subtotal** (sum of price × quantity).
- Cart and Checkout both derive tax/delivery/total from `CartPricing`.
- The old `Environment.defaultDeliveryFee` is kept as an alias so
  `checkout_screen.dart` and any other caller keep compiling; new code uses
  `CartPricing`.
- Figma's `$20.00 / $5.00 / $3.00 / $40.00` are **illustration values** of a
  2-item cart — they are *not* copied into code. Real values come from
  `ProductCart.price`.

---

## 5. Scroll behaviour (explicit requirement)

> *"có thể scroll nếu mục quá dài"*

The panel body is a `SingleChildScrollView`; the **Checkout button is pinned**
to the bottom of the panel (outside the scroll area) so it never scrolls away.
The summary block lives *inside* the scroll area, above the items' overflow,
matching Figma's vertical order.

For the checkout page (4.3-C) the whole page is one `SingleChildScrollView`
with a pinned "Place Order" bar at the bottom.

Minimum supported height is 568 px (iPhone SE) — the empty state uses a
`LayoutBuilder` so the illustration shrinks instead of overflowing.

---

## 6. State & data flow

```
CartBloc (existing, unchanged)
  ├── OnAddProductToCartEvent       → item enters the cart
  ├── OnIncreaseQuantityProductToCartEvent(idx)
  ├── OnDecreaseProductQuantityToCartEvent(idx)
  ├── OnDeleteProductToCartEvent(idx)
  └── OnClearCartEvent              → after a successful order

CartPanel (StatelessWidget)
  └── BlocBuilder<CartBloc, CartState>
        ├── products.isEmpty → CartEmptyState
        └── else            → scrollable list + CartSummary + pinned Checkout
```

The quantity stepper dispatches by **index**, matching the existing bloc
contract. Because the list is rebuilt from state on every change, indices stay
consistent.

---

## 7. Error / edge cases

| Case | Behaviour |
|---|---|
| Cart empty | Panel shows 4.3-A empty state; the Checkout button is not rendered at all. |
| Quantity at 1 | `−` is disabled (no visual change, no event dispatched). |
| Quantity at 99 | `+` is disabled (bloc already caps at 99). |
| Item image missing | `ImageResolver.resolveWidget` with `assets/figma_home/card_best_1.png` fallback. |
| Very long product name | `maxLines: 2` + `TextOverflow.ellipsis`. |
| Panel on a 320 px phone | Panel width = `min(330, width × 0.84)` so the backdrop strip always stays visible. |
| Total is 0 with items present | Checkout still enabled — a free order is legitimate. |

---

## 8. Testing

New `test/cart_panel_test.dart`:

1. Empty cart renders the 4.3-A headline *"Want to add something?"*.
2. Populated cart renders one row per product and the correct item count.
3. The summary shows subtotal / tax / delivery / total computed from
   `CartPricing` — asserts the numbers are **derived**, not hardcoded.
4. Tapping `+` increments the quantity and the line total.
5. Tapping `−` at quantity 1 is a no-op.
6. A long list scrolls: the summary and the Checkout button stay reachable.
7. Golden test for both 4.3-A and 4.3-B states.

Existing `test/cart_bloc_test.dart` must keep passing (bloc contract unchanged).

---

## 9. Implementation order

1. `CartPricing` in `environment.dart`.
2. `assets/figma_cart/*` → register `assets/figma_cart/` in `pubspec.yaml`.
3. `cart_panel.dart` + `cart_empty_state.dart` (4.3-A).
4. `cart_item_row.dart` + `cart_quantity_stepper.dart` (4.3-B).
5. `cart_summary.dart`.
6. `cart_screen.dart` → host the panel; wire `_openCart()` on Home.
7. `checkout_screen.dart` → re-skin to 4.3-C.
8. Tests + golden.
