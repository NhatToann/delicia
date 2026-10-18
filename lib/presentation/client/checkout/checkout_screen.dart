import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../data/env/environment.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/cart/cart_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/address.dart';
import '../../../domain/models/type_payment.dart';
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../helpers/modal_loading.dart';
import '../../helpers/modal_success.dart';
import '../../themes/colors_frave.dart';
import 'widgets/address_selector.dart';
import 'widgets/payment_method_selector.dart';

/// CheckoutScreen — assembles the address, payment, and summary sections,
/// then submits via [OrdersBloc.OnAddNewOrdersEvent] (UC-04).
///
/// The address list is currently the [Address.hardcodedDefault] placeholder
/// until Member A merges UC-06 (profile + address management).
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final Address _selectedAddress;
  TypePaymentMethod _payment = defaultPaymentMethod;

  @override
  void initState() {
    super.initState();
    _selectedAddress = Address.hardcodedDefault;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final cart = context.watch<CartBloc>().state;
    final orders = context.read<OrdersBloc>();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          onPressed: () => context.pop(),
        ),
        title: const TextCustom('Checkout', fontWeight: FontWeight.w500),
        centerTitle: true,
      ),
      body: BlocConsumer<OrdersBloc, OrdersState>(
        listenWhen: (a, b) =>
            a.isLoading != b.isLoading || a.error != b.error || a.lastOrder != b.lastOrder,
        listener: (_, state) async {
          if (!mounted) return;
          if (state.isLoading) {
            await modalLoading(context);
          } else if (Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          if (!mounted) return;
          if (state.error != null) {
            if (!context.mounted) return;
            errorMessageSnack(context, state.error!);
          } else if (state.lastOrder != null) {
            if (!context.mounted) return;
            context.read<CartBloc>().add(const OnClearCartEvent());
            await modalSuccess(context, 'Order placed!');
            if (!mounted) return;
            if (!context.mounted) return;
            context.go('/client/orders');
          }
        },
        builder: (_, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            children: [
              const _SectionTitle('Shipping Address'),
              _Card(
                child: AddressSelector(
                  addresses: const [Address.hardcodedDefault],
                  selectedId: _selectedAddress.id,
                  onSelect: (a) => setState(() => _selectedAddress = a),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Payment Methods'),
              _Card(
                child: PaymentMethodSelector(
                  selected: _payment,
                  onSelected: (m) => setState(() => _payment = m),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Order Summary'),
              _Card(
                child: _Summary(total: cart.total),
              ),
              const SizedBox(height: 20),
              BtnFrave(
                text: 'Confirm Order  \$${cart.total.toStringAsFixed(2)}',
                onPressed: (cart.products == null || cart.products!.isEmpty)
                    ? null
                    : () => _submit(orders, auth.user?.uid ?? '', cart.total),
              ),
            ],
          );
        },
      ),
    );
  }

  void _submit(OrdersBloc orders, String clientId, double total) {
    final products = context.read<CartBloc>().state.products ?? const [];
    if (products.isEmpty) {
      errorMessageSnack(context, 'Your cart is empty.');
      return;
    }
    orders.add(OnAddNewOrdersEvent(
      clientId: clientId,
      address: _selectedAddress,
      paymentMethod: _payment.type,
      products: products,
      amount: total,
    ));
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: TextCustom(
        text,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _Summary extends StatelessWidget {
  final double total;
  const _Summary({required this.total});

  @override
  Widget build(BuildContext context) {
    final fee = Environment.defaultDeliveryFee;
    final subtotal = (total - fee).clamp(0, double.infinity).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TextCustom('Order Summary', fontWeight: FontWeight.w500),
        const Divider(),
        _row('Subtotal', '\$${subtotal.toStringAsFixed(2)}', grey: true),
        const SizedBox(height: 10),
        _row('IGV', '\$2.50', grey: true),
        const SizedBox(height: 10),
        _row('Shipping', '\$0.00', grey: true),
        const Divider(),
        _row('Total', '\$${total.toStringAsFixed(2)}', bold: true),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false, bool grey = false}) {
    final color = grey ? Colors.grey : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextCustom(
          label,
          color: color,
          fontWeight: bold ? FontWeight.w500 : FontWeight.normal,
        ),
        TextCustom(
          value,
          color: color,
          fontWeight: bold ? FontWeight.w500 : FontWeight.normal,
        ),
      ],
    );
  }
}