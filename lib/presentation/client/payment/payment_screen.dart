import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../data/env/environment.dart';
import '../../../data/services/route_service.dart';
import '../../../domain/bloc/address/address_bloc.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/cart/cart_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/address.dart';
import '../../../domain/models/client_address.dart';
import '../../../domain/models/lat_lng_point.dart';
import '../../../domain/models/price_breakdown.dart';
import '../../../domain/models/product_cart.dart';
import '../../../domain/models/type_payment.dart';
import '../../components/app_bottom_nav.dart';
import '../../components/app_nav_destination.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/modal_success.dart';
import '../../helpers/money.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import 'payment_geometry.dart';
import 'widgets/pay_now_button.dart';
import 'widgets/payment_header.dart';
import 'widgets/payment_method_glyph.dart';
import 'widgets/payment_method_sheet.dart';

/// PaymentScreen — address, order summary, payment method and total.
/// The summary scrolls independently from the pinned payment action.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, this.initialMethod});

  final TypePaymentMethod? initialMethod;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _voucherController = TextEditingController();
  final RouteService _routeService = RouteService();

  /// Address the user is delivering to.
  Address _address = Address.hardcodedDefault;

  /// Road distance in km from the restaurant to the delivery address.
  ///
  /// The delivery fee is derived from it, so it is recalculated whenever
  /// the address changes.
  double _distanceKm = 0.0;
  bool _calculatingDistance = false;

  /// Whether the address carries usable coordinates. When it does not, the
  /// flat default fee applies instead of a distance-based one.
  bool _hasCoordinates = false;

  /// The payment method currently selected.
  late TypePaymentMethod _method = widget.initialMethod ?? defaultPaymentMethod;

  _PaymentVoucher? _voucher;
  String? _voucherError;

  /// Whether the default address has already been taken from the profile.
  ///
  /// The address used to be re-synced from [AddressBloc] on **every**
  /// rebuild, which silently reverted a manual pick the moment the screen
  /// rebuilt (applying a voucher, for instance). The auto-assignment now
  /// happens exactly once; after that the address belongs to the user.
  bool _addressResolved = false;

  /// The money breakdown of the current cart.
  ///
  /// Every amount the screen prints comes from this one object, and it is
  /// the same object that gets persisted on the order — so the customer's
  /// screen, the courier's screen and the database can never disagree.
  PriceBreakdown breakdownFor(double subtotal) {
    final discount = _voucher?.subtotalDiscount(subtotal) ?? 0;
    final discountedSubtotal = subtotal - discount;
    final delivery = _voucher?.isFreeShipping == true ? 0.0 : _deliveryFeeVnd;
    return PriceBreakdown.from(
      subtotal: subtotal,
      tax: CartPricing.taxOf(discountedSubtotal),
      deliveryFee: delivery,
      discount: discount,
    );
  }

  static const List<_PaymentVoucher> _availableVouchers = [
    _PaymentVoucher.percent(code: 'DIS10', percent: 10),
    _PaymentVoucher.percent(code: 'DIS20', percent: 20),
    _PaymentVoucher.freeShipping(code: 'FREESHIP'),
  ];

  final List<TypePaymentMethod> _methods = <TypePaymentMethod>[
    defaultPaymentMethod,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthBloc>().state.user?.uid ?? '';
      // AddressBloc là tuỳ chọn — nếu app chưa mount nó thì bỏ qua việc nạp
      // danh sách địa chỉ, màn hình vẫn dùng địa chỉ mặc định hardcoded.
      final addressBloc = context.read<AddressBloc?>();
      if (uid.isNotEmpty && addressBloc != null) {
        addressBloc.add(OnLoadAddressesEvent(uid: uid));
      }
    });
    // The distance lookup touches the network, so it runs after the first
    // frame — calling setState from initState is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateDistanceAndFee(_address);
    });
  }

  @override
  void dispose() {
    _routeService.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  /// The delivery fee for the current distance, in dong.
  ///
  /// The app and the database both speak VND, so the fee is returned in
  /// the unit it is charged in — no conversion happens here.
  double get _deliveryFeeVnd => _hasCoordinates
      ? CartPricing.deliveryFeeVnd(_distanceKm)
      : Environment.defaultDeliveryFee;

  /// Works out how far the delivery address is from the restaurant.
  ///
  /// The road distance comes from OSRM; when the public demo server is
  /// unreachable the straight-line distance is used instead, so the screen
  /// always shows a fee.
  Future<void> _calculateDistanceAndFee(Address address) async {
    // An address without coordinates cannot be routed — fall back to the
    // flat default fee instead of pretending the customer is on the
    // other side of the planet.
    if (!mounted) return;
    if (!address.hasCoordinates) {
      setState(() {
        _distanceKm = 0.0;
        _hasCoordinates = false;
        _calculatingDistance = false;
      });
      return;
    }
    setState(() => _calculatingDistance = true);
    double distKm = 0.0;
    const origin = LatLngPoint(
      latitude: Environment.restaurantLatitude,
      longitude: Environment.restaurantLongitude,
    );
    final dest = LatLngPoint(
      latitude: address.latitude,
      longitude: address.longitude,
    );
    try {
      final route = await _routeService.getRoute(
        origin: origin,
        destination: dest,
      );
      distKm = route.distanceMeters / 1000.0;
    } catch (_) {
      // Fallback: great-circle distance * 1.2
      final directMeters = RouteService.distanceMeters(origin, dest);
      distKm = (directMeters * 1.2) / 1000.0;
    }
    if (!mounted) return;
    setState(() {
      _distanceKm = distKm;
      _hasCoordinates = true;
      _calculatingDistance = false;
    });
  }

  void _applyVoucher(String rawCode) {
    final code = rawCode.trim().toUpperCase();
    _PaymentVoucher? selected;
    for (final voucher in _availableVouchers) {
      if (voucher.code == code) {
        selected = voucher;
        break;
      }
    }
    setState(() {
      _voucher = selected;
      _voucherError = selected == null ? context.l10n.paymentVoucherInvalid : null;
      if (selected != null) _voucherController.text = selected.code;
    });
  }

  Future<void> _chooseVoucher() async {
    final selected = await showModalBottomSheet<_PaymentVoucher>(
      context: context,
      backgroundColor: ColorsFrave.surfaceColor,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.paymentVoucherAvailable,
                style: FraveText.bold(20, color: ColorsFrave.ink),
              ),
              const SizedBox(height: 8),
              for (final voucher in _availableVouchers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.local_offer_outlined,
                    color: ColorsFrave.navOrange,
                  ),
                  title: Text(
                    voucher.code,
                    style: FraveText.semiBold(15, color: ColorsFrave.ink),
                  ),
                  subtitle: Text(_voucherDescription(context, voucher)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(sheetContext, voucher),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    _applyVoucher(selected.code);
  }

  void _removeVoucher() {
    setState(() {
      _voucher = null;
      _voucherError = null;
      _voucherController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final cart = context.watch<CartBloc>().state;
    final orders = context.read<OrdersBloc>();
    // AddressBloc là tuỳ chọn — app thường mount nó, nhưng widget test / màn
    // hình nhúng có thể không có. Khi thiếu thì dùng địa chỉ mặc định.
    final addressBloc = context.watch<AddressBloc?>();
    final products = cart.products ?? const <ProductCart>[];

    // Tự động gán địa chỉ mặc định hoặc địa chỉ đầu tiên từ AddressBloc.
    //
    // CHỈ làm đúng một lần: trước đây việc này chạy lại ở mỗi rebuild, nên
    // một địa chỉ mà người dùng chọn tay bị ghi đè bằng địa chỉ mặc định
    // mỗi khi màn hình dựng lại (ví dụ khi áp voucher).
    final addresses = addressBloc?.state.addresses ?? const <ClientAddress>[];
    if (!_addressResolved && addresses.isNotEmpty) {
      final defaultAddr = addresses.firstWhere(
            (a) => a.isDefault == true,
        orElse: () => addresses.first,
      );
      // Map sang model Address chính thức của domain, CHỈ LẤY PHẦN TÊN ĐƯỜNG/SỐ NHÀ GỐC (trước dấu phẩy đầu tiên)
      // để tránh lỗi dồn ứ chuỗi lặp lại dài dằng dặc.
      final cleanStreet = defaultAddr.street.contains(',')
          ? defaultAddr.street.split(',').first.trim()
          : defaultAddr.street;

      _address = Address(
        id: defaultAddr.id,
        street: cleanStreet,
        reference: defaultAddr.reference,
        latitude: defaultAddr.latitude,
        longitude: defaultAddr.longitude,
      );
      _addressResolved = true;
      _calculateDistanceAndFee(_address);
    }

    return BlocConsumer<OrdersBloc, OrdersState>(
      listenWhen: (a, b) =>
      a.isLoading != b.isLoading || a.error != b.error || a.lastOrder != b.lastOrder,
      listener: (context, state) async {
        if (!context.mounted) return;
        if (state.isLoading) return;
        if (!context.mounted) return;
        if (state.error != null) {
          errorMessageSnack(context, state.error!);
        } else if (state.lastOrder != null) {
          context.read<CartBloc>().add(const OnClearCartEvent());
          await modalSuccess(context, context.l10n.paymentOrderPlacedSuccess);
          if (!context.mounted) return;
          context.go('/client/orders');
        }
      },
      builder: (context, orderState) {
        return Scaffold(
          backgroundColor: ColorsFrave.headerYellow,
          body: Column(
            children: <Widget>[
              const PaymentHeader(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: ColorsFrave.pageBg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(PaymentGeometry.sheetRadius),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: _PaymentBody(
                          products: products,
                          address: _address,
                          method: _method,
                          voucher: _voucher,
                          voucherController: _voucherController,
                          voucherError: _voucherError,
                          breakdown: breakdownFor(cart.total),
                          deliveryFee: _deliveryFeeVnd,
                          calculatingDistance: _calculatingDistance,
                          onPickAddress: _pickAddress,
                          onPickMethod: _pickMethod,
                          onEditItems: _editItems,
                          onApplyVoucher: _applyVoucher,
                          onChooseVoucher: _chooseVoucher,
                          onRemoveVoucher: _removeVoucher,
                        ),
                      ),
                      _PayNowBar(
                        enabled: products.isNotEmpty,
                        busy: orderState.isLoading,
                        onPressed: () => _pay(
                          orders,
                          auth.user?.uid ?? '',
                          cart.total,
                          products,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: AppNavDestination.home,
            onTap: (index) => AppNavDestination.go(context, index),
            showCart: false,
          ),
        );
      },
    );
  }

  Future<void> _pickAddress() async {
    // The map picker returns an [Address] that already carries the
    // coordinates, so the distance-based fee and the courier's navigation
    // both work. The profile address list is a management screen, not a
    // picker — it returns no address at all.
    final picked = await context.push<Address>('/client/select-address');
    if (picked == null || !mounted) return;

    // Làm sạch chuỗi street khi người dùng chọn địa chỉ thủ công
    final cleanStreet = picked.street.contains(',')
        ? picked.street.split(',').first.trim()
        : picked.street;

    setState(() {
      _address = Address(
        id: picked.id,
        street: cleanStreet,
        reference: picked.reference,
        latitude: picked.latitude,
        longitude: picked.longitude,
      );
      // The address now belongs to the user — never overwrite it with the
      // profile default again.
      _addressResolved = true;
    });
    await _calculateDistanceAndFee(_address);
  }

  Future<void> _pickMethod() async {
    final picked = await PaymentMethodSheet.show(
      context,
      selected: _method,
      methods: _methods,
    );
    if (picked == null || !mounted) return;
    setState(() => _method = picked);
  }

  Future<void> _editItems() async {
    await context.push('/client/cart');
  }

  Future<void> _pay(
      OrdersBloc orders,
      String clientId,
      double subtotal,
      List<ProductCart> products,
      ) async {
    if (products.isEmpty) {
      errorTextSnack(context, context.l10n.cartEmptyPeriod);
      return;
    }

    // Cash is the only method the checkout offers: it settles when the
    // courier hands the order over, so the order exists from the start.
    _createOrder(orders, clientId, subtotal, products);
  }

  void _createOrder(
    OrdersBloc orders,
    String clientId,
    double subtotal,
    List<ProductCart> products,
  ) {
    // The customer details are denormalised onto the order so the admin
    // console can show *who* ordered without a second lookup per row.
    final user = context.read<AuthBloc>().state.user;
    final breakdown = breakdownFor(subtotal);
    orders.add(
      OnAddNewOrdersEvent(
        clientId: clientId,
        clientName: user?.fullName ?? '',
        clientEmail: user?.email ?? '',
        address: _address,
        paymentMethod: _method.type,
        products: products,
        amount: breakdown.total.toDouble(),
        quote: breakdown,
        distanceKm: _distanceKm,
        receiverPhone: user?.phone,
        receiverName: user?.fullName,
      ),
    );
  }
}

enum _PaymentVoucherKind { percent, freeShipping }

class _PaymentVoucher {
  const _PaymentVoucher.percent({required this.code, required this.percent})
      : kind = _PaymentVoucherKind.percent;

  const _PaymentVoucher.freeShipping({required this.code})
      : kind = _PaymentVoucherKind.freeShipping,
        percent = 0;

  final String code;
  final _PaymentVoucherKind kind;
  final int percent;

  bool get isFreeShipping => kind == _PaymentVoucherKind.freeShipping;

  double subtotalDiscount(double subtotal) => isFreeShipping ? 0 : subtotal * percent / 100;

  /// What the voucher saves.
  ///
  /// A free-shipping voucher saves exactly the delivery fee that was
  /// charged, which depends on the distance — so the fee is passed in.
  double savings(double subtotal, {double deliveryFee = 0}) =>
      isFreeShipping ? deliveryFee : subtotalDiscount(subtotal);
}

String _voucherDescription(BuildContext context, _PaymentVoucher voucher) =>
    voucher.isFreeShipping
        ? context.l10n.paymentVoucherFreeShipping
        : context.l10n.paymentVoucherPercentOff(voucher.percent);

class _PaymentBody extends StatelessWidget {
  const _PaymentBody({
    required this.products,
    required this.address,
    required this.method,
    required this.voucher,
    required this.voucherController,
    required this.voucherError,
    required this.breakdown,
    required this.deliveryFee,
    required this.calculatingDistance,
    required this.onPickAddress,
    required this.onPickMethod,
    required this.onEditItems,
    required this.onApplyVoucher,
    required this.onChooseVoucher,
    required this.onRemoveVoucher,
  });

  final List<ProductCart> products;
  final Address address;
  final TypePaymentMethod method;
  final _PaymentVoucher? voucher;
  final TextEditingController voucherController;
  final String? voucherError;

  /// The itemised money breakdown.
  ///
  /// This is the same object that is persisted on the order, so the total
  /// printed here is exactly the number the courier will collect.
  final PriceBreakdown breakdown;

  /// The delivery fee, in dong — derived from the road distance.
  final double deliveryFee;

  /// Whether the distance (and therefore the fee) is still being worked out.
  final bool calculatingDistance;
  final VoidCallback onPickAddress;
  final VoidCallback onPickMethod;
  final VoidCallback onEditItems;
  final ValueChanged<String> onApplyVoucher;
  final VoidCallback onChooseVoucher;
  final VoidCallback onRemoveVoucher;

  double get _subtotal => products.fold(
    0,
        (sum, product) => sum + (product.price * product.quantity),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PaymentSectionHeading(
            title: l10n.paymentShippingAddress,
            onEdit: onPickAddress,
          ),
          const SizedBox(height: 10),
          Material(
            color: ColorsFrave.pillYellow,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPickAddress,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: ColorsFrave.primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        address.street,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FraveText.medium(15, color: ColorsFrave.ink),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      color: ColorsFrave.greyText,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          _PaymentSectionHeading(
            title: l10n.paymentOrderSummary,
            onEdit: onEditItems,
          ),
          const SizedBox(height: 8),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                l10n.cartEmptyPeriod,
                style: FraveText.regular(14, color: ColorsFrave.greyText),
              ),
            )
          else
            for (final product in products) ...[
              const SizedBox(height: 10),
              _PaymentProductRow(product: product),
            ],
          const SizedBox(height: 18),
          const _PaymentDivider(),
          const SizedBox(height: 18),
          _PaymentSectionHeading(
            title: l10n.paymentMethod,
            onEdit: onPickMethod,
          ),
          const SizedBox(height: 10),
          Material(
            color: ColorsFrave.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onPickMethod,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ColorsFrave.outlineVariant),
                ),
                child: Row(
                  children: [
                    PaymentMethodGlyph(method: method, width: 34, height: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paymentMethodLabel(l10n, method),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FraveText.semiBold(
                              15,
                              color: ColorsFrave.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.paymentPayWhenReceive,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FraveText.regular(
                              13,
                              color: ColorsFrave.greyText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: ColorsFrave.greyText,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const _PaymentDivider(),
          const SizedBox(height: 18),
          Text(
            l10n.paymentDeliveryTime,
            style: FraveText.semiBold(18, color: ColorsFrave.ink),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.paymentEstimatedDelivery,
                  style: FraveText.regular(14, color: ColorsFrave.greyText),
                ),
              ),
              Text(
                l10n.paymentEstimatedMinutes(
                  Environment.estimatedDeliveryMinutes,
                ),
                style: FraveText.semiBold(16, color: ColorsFrave.navOrange),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.paymentVoucherTitle,
                  style: FraveText.semiBold(18, color: ColorsFrave.ink),
                ),
              ),
              TextButton.icon(
                onPressed: onChooseVoucher,
                icon: const Icon(Icons.local_offer_outlined, size: 17),
                label: Text(l10n.paymentVoucherSelect),
                style: TextButton.styleFrom(
                  foregroundColor: ColorsFrave.navOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: voucherController,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: onApplyVoucher,
                  decoration: InputDecoration(
                    hintText: l10n.paymentVoucherHint,
                    prefixIcon: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 19,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: ColorsFrave.surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: ColorsFrave.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: ColorsFrave.outlineVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => onApplyVoucher(voucherController.text),
                style: FilledButton.styleFrom(
                  backgroundColor: ColorsFrave.navOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(l10n.paymentVoucherApply),
              ),
            ],
          ),
          if (voucherError != null) ...[
            const SizedBox(height: 4),
            Text(
              voucherError!,
              style: FraveText.regular(13, color: ColorsFrave.errorColor),
            ),
          ],
          if (voucher != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.paymentVoucherApplied(voucher!.code),
                    style: FraveText.medium(
                      13,
                      color: ColorsFrave.successColor,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRemoveVoucher,
                  child: Text(l10n.paymentVoucherRemove),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _PaymentBreakdownRow(
            label: l10n.cartSummarySubtotal,
            amount: breakdown.subtotal.toDouble(),
          ),
          const SizedBox(height: 8),
          _PaymentBreakdownRow(
            label: l10n.cartSummaryTax,
            amount: breakdown.tax.toDouble(),
          ),
          const SizedBox(height: 8),
          _PaymentBreakdownRow(
            label: l10n.cartSummaryDelivery,
            amount: breakdown.delivery.toDouble(),
            loading: calculatingDistance,
          ),
          if (voucher != null) ...[
            const SizedBox(height: 8),
            _PaymentBreakdownRow(
              label: l10n.paymentVoucherDiscount(voucher!.code),
              amount: -voucher!.savings(_subtotal, deliveryFee: deliveryFee),
              isDiscount: true,
            ),
          ],
          const SizedBox(height: 12),
          const _PaymentDivider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.cartSummaryTotal,
                  style: FraveText.semiBold(19, color: ColorsFrave.ink),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  Money.format(breakdown.total),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.bold(19, color: ColorsFrave.navOrange),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentBreakdownRow extends StatelessWidget {
  const _PaymentBreakdownRow({
    required this.label,
    required this.amount,
    this.isDiscount = false,
    this.loading = false,
  });

  final String label;
  final double amount;
  final bool isDiscount;

  /// Whether the amount is still being computed — the row shows a dash
  /// instead of a number until it is known.
  final bool loading;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: FraveText.regular(
            14,
            color: isDiscount ? ColorsFrave.successColor : ColorsFrave.greyText,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        loading ? '—' : Money.format(amount),
        textAlign: TextAlign.end,
        style: FraveText.medium(
          14,
          color: isDiscount ? ColorsFrave.successColor : ColorsFrave.ink,
        ),
      ),
    ],
  );
}

class _PaymentSectionHeading extends StatelessWidget {
  const _PaymentSectionHeading({required this.title, required this.onEdit});

  final String title;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: FraveText.semiBold(18, color: ColorsFrave.ink),
        ),
      ),
      TextButton(
        onPressed: onEdit,
        style: TextButton.styleFrom(
          foregroundColor: ColorsFrave.primaryColor,
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          context.l10n.actionEdit,
          style: FraveText.medium(14, color: ColorsFrave.primaryColor),
        ),
      ),
    ],
  );
}

class _PaymentProductRow extends StatelessWidget {
  const _PaymentProductRow({required this.product});

  final ProductCart product;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          product.nameProduct,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FraveText.medium(15, color: ColorsFrave.ink),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '×${product.quantity}',
        style: FraveText.medium(14, color: ColorsFrave.greyText),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 104,
        child: Text(
          Money.format(product.price * product.quantity),
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FraveText.semiBold(15, color: ColorsFrave.ink),
        ),
      ),
    ],
  );
}

class _PaymentDivider extends StatelessWidget {
  const _PaymentDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: ColorsFrave.dividerOrange);
}

class _PayNowBar extends StatelessWidget {
  const _PayNowBar({
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorsFrave.pageBg,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: PayNowButton(enabled: enabled, busy: busy, onPressed: onPressed),
    );
  }
}