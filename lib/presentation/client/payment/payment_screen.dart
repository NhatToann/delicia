import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/env/environment.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/cart/cart_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/bloc/payment/payment_bloc.dart';
import '../../../domain/models/address.dart';
import '../../../domain/models/product_cart.dart';
import '../../../domain/models/type_payment.dart';
import '../../../domain/services/app_failure.dart';
import '../../../domain/services/payment_gateway.dart';
import '../../components/app_bottom_nav.dart';
import '../../components/app_nav_destination.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/modal_success.dart';
import '../../helpers/money.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import 'payment_geometry.dart';
import 'widgets/payment_header.dart';
import 'widgets/payment_method_glyph.dart';
import 'widgets/payment_method_sheet.dart';
import 'widgets/pay_now_button.dart';

/// PaymentScreen — address, order summary, payment method and total.
/// The summary scrolls independently from the pinned payment action.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, this.initialMethod});

  /// The method selected when the screen opens.
  ///
  /// Defaults to [defaultPaymentMethod] — cash, which needs no gateway and
  /// can be settled the moment the order is created. The design frames use
  /// the credit card instead, so this exists to let a preview or a test
  /// reproduce them.
  final TypePaymentMethod? initialMethod;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _voucherController = TextEditingController();

  /// Address the user is delivering to. Seeded with the default one and
  /// replaced when the picker returns a new one.
  Address _address = Address.hardcodedDefault;

  /// The payment method currently selected.
  late TypePaymentMethod _method = widget.initialMethod ?? defaultPaymentMethod;

  _PaymentVoucher? _voucher;
  String? _voucherError;

  static const List<_PaymentVoucher> _availableVouchers = [
    _PaymentVoucher.percent(code: 'DIS10', percent: 10),
    _PaymentVoucher.percent(code: 'DIS20', percent: 20),
    _PaymentVoucher.freeShipping(code: 'FREESHIP'),
  ];

  /// The methods the user can pick from.
  ///
  /// The checkout offers only cash and payOS.
  final List<TypePaymentMethod> _methods = <TypePaymentMethod>[
    defaultPaymentMethod,
    payOsPaymentMethod,
  ];

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
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
      _voucherError = selected == null
          ? context.l10n.paymentVoucherInvalid
          : null;
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

  double _amountToPay(double subtotal) {
    final discountedSubtotal =
        subtotal - (_voucher?.subtotalDiscount(subtotal) ?? 0);
    final total = CartPricing.totalOf(discountedSubtotal);
    return _voucher?.isFreeShipping == true
        ? total - CartPricing.deliveryFee
        : total;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final cart = context.watch<CartBloc>().state;
    final orders = context.read<OrdersBloc>();
    final products = cart.products ?? const <ProductCart>[];

    return BlocConsumer<OrdersBloc, OrdersState>(
      listenWhen: (a, b) =>
          a.isLoading != b.isLoading ||
          a.error != b.error ||
          a.lastOrder != b.lastOrder,
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
          // The yellow bleeds behind the white content sheet so the sheet's
          // 30 px rounded top corners read exactly like the Figma frame.
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
                          onPickAddress: _pickAddress,
                          onPickMethod: _pickMethod,
                          onEditItems: _editItems,
                          onApplyVoucher: _applyVoucher,
                          onChooseVoucher: _chooseVoucher,
                          onRemoveVoucher: _removeVoucher,
                        ),
                      ),
                      // Pinned CTA.
                      _PayNowBar(
                        enabled: products.isNotEmpty,
                        busy:
                            orderState.isLoading ||
                            context.select<PaymentBloc, bool>(
                              (bloc) => bloc.state.isBusy,
                            ),
                        onPressed: () => _pay(
                          orders,
                          auth.user?.uid ?? '',
                          _amountToPay(cart.total),
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
            // The customer is already at checkout — a cart button here
            // would be a dead end, so the bar shows the four destinations
            // only.
            showCart: false,
          ),
        );
      },
    );
  }

  /// Opens the address picker and uses whatever comes back.
  Future<void> _pickAddress() async {
    final picked = await context.push<Address>('/client/select-address');
    if (picked == null || !mounted) return;
    setState(() => _address = picked);
  }

  /// Opens the method sheet and applies the choice.
  Future<void> _pickMethod() async {
    final picked = await PaymentMethodSheet.show(
      context,
      selected: _method,
      methods: _methods,
    );
    if (picked == null || !mounted) return;
    setState(() => _method = picked);
  }

  /// Lets the user change the items from the cart.
  Future<void> _editItems() async {
    await context.push('/client/cart');
  }

  /// Runs the payment.
  ///
  /// Cash creates the order straight away. A gateway method first opens the
  /// hosted checkout page and only creates the order once the gateway
  /// confirms the money arrived.
  Future<void> _pay(
    OrdersBloc orders,
    String clientId,
    double total,
    List<ProductCart> products,
  ) async {
    if (products.isEmpty) {
      errorTextSnack(context, context.l10n.cartEmptyPeriod);
      return;
    }

    if (!_method.requiresGateway) {
      _createOrder(orders, clientId, total, products);
      return;
    }

    if (!Environment.payosConfigured) {
      errorTextSnack(context, context.l10n.paymentPayOsUnavailable);
      return;
    }

    final bloc = context.read<PaymentBloc>();
    bloc.add(
      OnStartPayOsPayment(
        amount: total,
        orderCode: _orderCode(),
        description: context.l10n.paymentOrderDescription,
        products: products,
        returnUrl: 'https://delicia.app/payment/success',
        cancelUrl: 'https://delicia.app/payment/cancel',
        buyerEmail: context.read<AuthBloc>().state.user?.email,
        buyerName: context.read<AuthBloc>().state.user?.fullName,
      ),
    );

    await bloc.stream.firstWhere((state) {
      final status = state.status;
      return status == PaymentStatus.awaitingUser ||
          status == PaymentStatus.failed;
    });

    if (!mounted) return;
    final state = bloc.state;
    if (state.status == PaymentStatus.failed) {
      errorMessageSnack(
        context,
        state.error ?? const AppFailure(AppFailureCodes.paymentStart),
      );
      return;
    }
    final url = state.checkoutUrl;
    if (url == null) return;

    final opened = await _openExternally(url);
    if (!opened || !mounted) return;

    // The user comes back from the gateway — ask it whether the money
    // arrived before creating the order.
    bloc.add(OnVerifyPayOsPayment());
    await bloc.stream.firstWhere((s) {
      final status = s.status;
      return status == PaymentStatus.paid ||
          status == PaymentStatus.failed ||
          status == PaymentStatus.cancelled;
    });

    if (!mounted) return;
    final finalState = bloc.state;
    if (finalState.status == PaymentStatus.paid) {
      _createOrder(orders, clientId, total, products);
      return;
    }
    if (finalState.error != null) {
      errorMessageSnack(context, finalState.error!);
    }
  }

  /// Opens [url] in the system browser.
  ///
  /// Returns false when no browser could handle it, so the caller can tell
  /// the user instead of silently doing nothing.
  Future<bool> _openExternally(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  void _createOrder(
    OrdersBloc orders,
    String clientId,
    double total,
    List<ProductCart> products,
  ) {
    orders.add(
      OnAddNewOrdersEvent(
        clientId: clientId,
        address: _address,
        paymentMethod: _method.type,
        products: products,
        amount: total,
      ),
    );
  }

  /// A numeric order code the gateway accepts.
  String _orderCode() =>
      DateTime.now().millisecondsSinceEpoch.toString().substring(5);
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

  double subtotalDiscount(double subtotal) =>
      isFreeShipping ? 0 : subtotal * percent / 100;

  double savings(double subtotal) =>
      isFreeShipping ? CartPricing.deliveryFee : subtotalDiscount(subtotal);
}

String _voucherDescription(BuildContext context, _PaymentVoucher voucher) =>
    voucher.isFreeShipping
    ? context.l10n.paymentVoucherFreeShipping
    : context.l10n.paymentVoucherPercentOff(voucher.percent);

/// Responsive payment summary. Rows use available width so Vietnamese labels
/// and VND amounts stay inside the card on narrow devices.
class _PaymentBody extends StatelessWidget {
  const _PaymentBody({
    required this.products,
    required this.address,
    required this.method,
    required this.voucher,
    required this.voucherController,
    required this.voucherError,
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
  final VoidCallback onPickAddress;
  final VoidCallback onPickMethod;
  final VoidCallback onEditItems;
  final ValueChanged<String> onApplyVoucher;
  final VoidCallback onChooseVoucher;
  final VoidCallback onRemoveVoucher;

  double get _subtotal => products.fold(
    0,
    (sum, product) => sum + product.price * product.quantity,
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
                            method.uid == 'CASH'
                                ? l10n.paymentPayWhenReceive
                                : l10n.paymentMethodPayOs,
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
            amount: _subtotal,
          ),
          const SizedBox(height: 8),
          _PaymentBreakdownRow(
            label: l10n.cartSummaryTax,
            amount: CartPricing.taxOf(
              _subtotal - (voucher?.subtotalDiscount(_subtotal) ?? 0),
            ),
          ),
          const SizedBox(height: 8),
          _PaymentBreakdownRow(
            label: l10n.cartSummaryDelivery,
            amount: voucher?.isFreeShipping == true
                ? 0
                : CartPricing.deliveryFee,
          ),
          if (voucher != null) ...[
            const SizedBox(height: 8),
            _PaymentBreakdownRow(
              label: l10n.paymentVoucherDiscount(voucher!.code),
              amount: -voucher!.savings(_subtotal),
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
                  Money.format(
                    CartPricing.totalOf(
                          _subtotal -
                              (voucher?.subtotalDiscount(_subtotal) ?? 0),
                        ) -
                        (voucher?.isFreeShipping == true
                            ? CartPricing.deliveryFee
                            : 0),
                  ),
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
  });

  final String label;
  final double amount;
  final bool isDiscount;

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
        Money.format(amount),
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

/// The pinned payment action, sized for a comfortable tap target.
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
