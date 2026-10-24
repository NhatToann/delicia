import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/date_custom.dart';
import '../../helpers/error_message.dart';
import '../../themes/colors_frave.dart';

/// ClientOrdersScreen — placeholder list of the current client's orders.
///
/// Reads the last completed order from [OrdersBloc] (set after checkout)
/// and shows it in a single card. Full history belongs to Member A
/// (UC-05), but the Leader's checkout flow needs a destination that
/// confirms "your order was placed".
class ClientOrdersScreen extends StatelessWidget {
  const ClientOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          onPressed: () => context.pop(),
        ),
        title:
            const TextCustom('My Orders', fontWeight: FontWeight.bold),
        centerTitle: true,
      ),
      body: BlocBuilder<OrdersBloc, OrdersState>(
        builder: (_, state) {
          final order = state.lastOrder;
          if (order == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 96,
                      color: ColorsFrave.greyText,
                    ),
                    const SizedBox(height: 16),
                    const TextCustom(
                      'No orders yet',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 8),
                    const TextCustom(
                      'Place an order to see it here.',
                      color: ColorsFrave.greyText,
                    ),
                    const SizedBox(height: 24),
                    BtnFrave(
                      text: 'Start Shopping',
                      onPressed: () => context.go('/client/home'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 8),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextCustom(
                    'Order #${order.id}',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  const SizedBox(height: 6),
                  TextCustom(
                    DateCustom.getRelativeTime(order.createdAt),
                    color: ColorsFrave.greyText,
                    fontSize: 13,
                  ),
                  const Divider(),
                  for (final p in order.products)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextCustom(
                              '${p.nameProduct} x ${p.quantity}',
                            ),
                          ),
                          TextCustom(
                            '\$${p.total.toStringAsFixed(2)}',
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const TextCustom(
                        'Total',
                        fontWeight: FontWeight.bold,
                      ),
                      TextCustom(
                        '\$${order.amount.toStringAsFixed(2)}',
                        fontWeight: FontWeight.bold,
                        color: ColorsFrave.primaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BtnFrave(
                    text: order.canTrackDelivery
                        ? 'Track Delivery'
                        : 'Awaiting Restaurant',
                    color: order.canTrackDelivery
                        ? ColorsFrave.primaryColor
                        : ColorsFrave.greyText,
                    onPressed: order.canTrackDelivery
                        ? () => context.push('/client/map')
                        : () => errorMessageSnack(
                              context,
                              'Your order has not been dispatched yet. '
                              'Live tracking will open once it is on the way.',
                            ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}