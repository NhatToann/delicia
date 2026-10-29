# Payment Screen — Design Spec (Figma 4.3 - D)

**Date:** 2026-10-24
**Scope:** UC-04 — replace the Checkout step with a single **Payment** step (Cart → Payment → Order confirmed)
**Figma file:** `tVh0aA6EL18IotmAMXwO3p` ("Food Delivery App UI Kit")
**Figma node:** `202:2956` ("4.3 - D - Payment"), 393 x 852 frame
**Local reference:** `assets/Food Delivery App UI Kit .../4.3 - D - Payment.png`

---

## 1. Decisions taken

| Question | Decision |
|---|---|
| Flow | **Cart → Payment directly.** The cart panel's "Checkout" button now pushes `/client/payment`. The old 4.3-C Checkout screen is **deleted** — 4.3-D is a strict superset of it (address + order summary + a new payment-method + delivery-time section + the Pay Now CTA), so keeping both would have duplicated the same data in two places. |
| Payment methods | **Cash first** (`CASH PAYMENT` is the default selection). `PAYPAL` / `GOOGLE PAY` / `MERCADO PAGO` stay in the catalogue but are secondary. **PayOS** is added as a real gateway, **enabled only when merchant credentials are configured** — see §6. |
| Payment method UI | The section shows the **currently selected method** (icon + name + a cream pill with the masked card number / descriptor). The peach **"Edit"** chip opens a bottom sheet with the full list. |
| Address | The pencil next to "Shipping Address" opens the existing `/client/select-address` picker and uses the returned `Address`. |
| Money | Every amount is derived (`CartPricing` + real `ProductCart.price`). The Figma sample values (`$40.00`, `25 mins`) are layout samples, not data. |
| Bottom nav | The Figma frame carries the app's orange bottom bar (`assets/figma_home/footer.svg`, 393 x 61, y791). It is rendered 1:1 but is **not yet interactive** — wiring it to the real navigation is a follow-up. |

---

## 2. Geometry (393 x 852 frame)

Measured off the Figma PNG and the `get_metadata` node map.

### Chrome
| Element | Value |
|---|---|
| Frame | 393 x 852, background `#F8F8F8`, corner radius 20 |
| Status bar | 0..31 — yellow `#F5CB58` (Android draws its own; the Figma clock/wifi/battery are part of the mock) |
| Yellow band | 0..131 (`32` status + `100` content) |
| White sheet | starts at y132, rounded top corners r30, extends to y852 |
| Footer | 393 x 61 at y791, orange `#E95322`, rounded top corners r30 |

### Header
| Element | Geometry |
|---|---|
| Title "Payment" | League Spartan **Bold 28**, `#F8F8F8`, centred, text box y73 |
| Back arrow | 8 x 13 at x35 y81, orange (`assets/figma_cart/back_arrow.svg`) |

### Body rows (Figma y)
| Element | Geometry |
|---|---|
| "Shipping Address" | **Bold 24**, `#391713`, x46, y172 (box h26) |
| Pencil icon | 10 x 10.71 at x239 y175 (`assets/figma_cart/edit_icon.svg`) |
| Address card | `#F3E9B5`, x35 y209, 323 x 35, radius 20 |
| Address text | **Regular 16**, `#391713`, x48, y221 |
| "Order Summary" | **Medium 20**, `#391713`, x35, y293 |
| "Edit" chip (summary) | 58 x 14 at x300 y293, radius 38, bg `#FFDECF`, label **Regular 6** `#E95322` |
| Item row | name **Light 14** x35 / qty **Light 14** `#E95322` / price **Medium 20** `#391713` right-aligned at x358; row 1 y322, row 2 y338 (pitch 16) |
| Divider 1 | 1 px `#FFD8C7`, x34, y371 |
| "Payment Method" | **Medium 20**, x35, y399 |
| "Edit" chip (payment) | 58 x 14 at x300 y399 |
| Method icon | 31 x 21.2 at x35 y426 (Figma card glyph = `assets/figma_payment/card_icon.svg`) |
| Method name | **Light 14**, x75, y431 |
| Method pill | `#F3E9B5`, x200 y426, 157 x 17, radius 9.72, text **Light 14** at x210 |
| Divider 2 | 1 px `#FFD8C7`, x35, y471 |
| "Delivery Time" | **Medium 20**, x35, y501 |
| "Estimated Delivery" | **Light 14**, x35, y531 |
| "25 mins" | **Medium 20**, `#E95322`, x292, y529 |
| Divider 3 | 1 px `#FFD8C7`, x35, y582 |
| "Pay Now" | 157.43 x 38 at x123 y717, radius 38, bg `#FFDECF`, label **Regular 23.07** `#E95322` |

### The one intentional deviation
Figma 4.3-D draws **no money total**. A real screen that charges money has to show what is
being charged, so a **Total** row (**Medium 20**, label `#391713`, value `#E95322`) is added
directly under Divider 3 (y583). Everything above Divider 3 keeps its Figma coordinates.

---

## 3. Architecture

```
lib/
├── data/env/environment.dart        # + PayOS credentials, + delivery ETA, + VND rate
├── domain/
│   ├── models/type_payment.dart     # + PAYOS entry
│   ├── services/payment_gateway.dart # NEW — Cash + PayOS gateways
│   └── bloc/payment/                # NEW — PaymentBloc (link creation + verification)
├── presentation/client/payment/
│   ├── payment_screen.dart          # NEW — the screen
│   └── widgets/
│       ├── payment_header.dart      # NEW — yellow band + title + back arrow
│       ├── payment_method_sheet.dart # NEW — bottom sheet with the method list
│       ├── payment_footer.dart      # NEW — Figma bottom bar
│       └── pay_now_button.dart      # NEW — the CTA
└── router/app_router.dart           # + /client/payment, - /client/checkout
```

`lib/presentation/client/checkout/` is deleted (superseded by `payment/`).

---

## 4. Data flow

```
CartBloc.products ─┐
CartBloc.total   ──┼─> PaymentScreen
Address (picker) ──┘        │
                             ├─ CASH  ─> OrdersBloc.OnAddNewOrdersEvent ─> order created
                             │                                            └─> success modal
                             │                                                └─> /client/orders
                             └─ PAYOS ─> PaymentBloc.OnStartPayOsPayment
                                          ├─ create link -> external browser
                                          ├─ user returns -> OnVerifyPayOsPayment
                                          └─ PAID -> OrdersBloc.OnAddNewOrdersEvent
```

The screen never talks to the gateway directly — `PaymentBloc` owns the state machine and the
screen only reacts to its states (`idle / processing / awaitingPayment / paid / failed`).

---

## 5. Error handling

| Situation | Behaviour |
|---|---|
| Cart empty | "Pay Now" is disabled; tapping shows a snackbar |
| Order creation fails | `OrdersBloc.error` -> red snackbar, the screen stays put so the user can retry |
| PayOS not configured | The method is hidden from the list entirely (not shown as a broken option) |
| PayOS link creation fails | `PaymentBloc` emits `failed` -> snackbar with the gateway message, screen stays put |
| PayOS returns "CANCELLED" | Snackbar "Payment cancelled", the order is **not** created |
| PayOS link expires | Same as cancelled — the user can tap "Pay Now" again |

---

## 6. PayOS integration

payOS requires `clientId` + `apiKey` + `checksumKey` and an HMAC-SHA256 request signature.
The checksum key **must not** be embedded in a shipped app, so the integration is:

* fully implemented (`PayOsGateway` — create link, query status, verify response signature),
* **disabled by default** (`Environment.payosClientId` etc. are empty),
* enabled by filling the credentials in `lib/data/env/environment.dart` (or, in production,
  by pointing the gateway at a small backend that holds the key).

Amounts are converted to VND (`Environment.payosVndRate`, default 25 000) because payOS only
accepts integer VND.

---

## 7. Testing

`test/payment_geometry_test.dart` asserts the rendered geometry against the Figma node map
(title at y73, back arrow at x35/y81, address card at x35/y209 323x35, section titles at
y293 / y399 / y501, dividers at y371 / y471 / y582, the method pill at x200/y426, the Pay Now
button at x123/y717 157x38). `test/payment_gateway_test.dart` covers the PayOS signature
construction and the status mapping with a stubbed HTTP client.

## 8. Vouchers

The Payment screen accepts `DIS10` (10% off the item subtotal), `DIS20`
(20% off the item subtotal), and `FREESHIP` (waives the delivery fee). The
customer can type a code or choose one from the available-voucher sheet.
Discounts are applied before tax; the displayed total, cash order amount, and
PayOS amount all use the same discounted total. The selected code and savings
are shown in the payment breakdown.
