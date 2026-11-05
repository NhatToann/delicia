import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/driver_orders/driver_orders_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/delivery_status.dart';
import '../../../domain/models/order_record.dart';
import '../../../domain/services/storage_service.dart';
import '../../../domain/utils/driver_earnings.dart';
import '../../components/text_custom.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/money.dart';
import '../../themes/colors_frave.dart';
import 'widgets/cod_settlement_badge.dart';
import 'widgets/cod_settlement_sheet.dart';
import 'widgets/status_action_buttons.dart';

class DeliveryDetailsScreen extends StatefulWidget {
  final String orderId;
  final OrderRecord? order;

  const DeliveryDetailsScreen({
    super.key,
    required this.orderId,
    this.order,
  });

  @override
  State<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends State<DeliveryDetailsScreen> {
  final StorageService _storageService = FirebaseStorageService();
  final ImagePicker _picker = ImagePicker();

  OrderRecord? _order;
  bool _isUploadingPhoto = false;

  String get _driverId {
    try {
      final authState = context.read<AuthBloc>().state;
      return authState.user?.uid ?? 'driver_demo';
    } catch (_) {
      return 'driver_demo';
    }
  }

  void _confirmReject(OrderRecord order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const TextCustom('Từ chối đơn hàng', fontWeight: FontWeight.bold),
        content: TextCustom(
          'Bạn có chắc chắn muốn từ chối Đơn hàng #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}?',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TextCustom('Hủy', color: ColorsFrave.greyText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<DriverOrdersBloc>().add(
                    RejectOrderEvent(orderId: order.id, deliveryId: _driverId),
                  );
              context.pop();
            },
            child: const TextCustom('Từ chối', color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:${phoneNumber.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('Không thể thực hiện cuộc gọi đến $phoneNumber');
      }
    } catch (e) {
      _showSnack('Lỗi khi mở ứng dụng gọi điện: $e');
    }
  }

  Future<void> _sendSms(String phoneNumber) async {
    final uri = Uri.parse('sms:${phoneNumber.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('Không thể mở ứng dụng tin nhắn đến $phoneNumber');
      }
    } catch (e) {
      _showSnack('Lỗi khi mở ứng dụng tin nhắn: $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TextCustom(message, color: Colors.white),
        backgroundColor: ColorsFrave.darkText,
      ),
    );
  }

  Future<void> _handleUploadDeliveryProof(OrderRecord order) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TextCustom(
                'Ảnh xác nhận giao hàng',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              const SizedBox(height: 6),
              const TextCustom(
                'Vui lòng chụp ảnh món ăn đã giao tại vị trí của khách để hoàn tất đơn hàng.',
                color: ColorsFrave.greyText,
                fontSize: 13,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsFrave.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: const TextCustom(
                  'Chụp ảnh bằng Camera',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickAndComplete(order, ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.photo_library, color: ColorsFrave.darkText),
                label: const TextCustom(
                  'Chọn ảnh từ thư viện',
                  color: ColorsFrave.darkText,
                  fontWeight: FontWeight.bold,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickAndComplete(order, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Complete without photo if needed
                  _confirmCashSettlement(order, null);
                },
                child: const TextCustom(
                  'Hoàn tất không cần ảnh',
                  color: ColorsFrave.greyText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndComplete(OrderRecord order, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);

      final photoUrl = await _storageService.uploadImage(
        picked,
        folder: 'delivery_proofs',
      );

      setState(() => _isUploadingPhoto = false);

      _confirmCashSettlement(order, photoUrl);
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      _showSnack('Tải ảnh xác nhận thất bại: $e');
    }
  }

  /// Asks the courier to confirm the cash settlement, then completes the
  /// delivery.
  ///
  /// The app is cash-on-delivery only, so "the order was delivered" and
  /// "the money was collected" are two facts about the same moment at the
  /// customer's door. Writing only the first one leaves the restaurant
  /// unable to tell cash it has from cash it is owed — which is why the
  /// settlement is a mandatory step, not an optional extra.
  Future<void> _confirmCashSettlement(
    OrderRecord order,
    String? deliveryPhoto,
  ) async {
    final collected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CodSettlementSheet(order: order),
    );

    // The courier dismissed the sheet — the delivery is not completed.
    if (collected == null) return;

    _transitionStatus(
      order,
      DeliveryStatus.delivered,
      deliveryPhoto,
      cashCollected: true,
      collectedAmountVnd: collected,
    );
  }

  void _transitionStatus(
    OrderRecord order,
    DeliveryStatus targetStatus,
    String? deliveryPhoto, {
    bool cashCollected = false,
    int? collectedAmountVnd,
  }) {
    final currentStatus = DeliveryStatus.fromString(order.status);
    if (targetStatus == DeliveryStatus.accepted) {
      String driverId = 'driver_demo';
      String driverName = 'Tài xế Delicia';
      try {
        final authState = context.read<AuthBloc>().state;
        driverId = authState.user?.uid ?? driverId;
        driverName = authState.user?.fullName ?? driverName;
      } catch (_) {}
      context.read<DriverOrdersBloc>().add(
            AcceptOrderEvent(
              orderId: order.id,
              deliveryId: driverId,
              deliveryName: driverName,
            ),
          );
      return;
    }
    context.read<DriverOrdersBloc>().add(
          UpdateOrderStatusEvent(
            orderId: order.id,
            currentStatus: currentStatus,
            targetStatus: targetStatus,
            deliveryPhoto: deliveryPhoto,
            cashCollected: cashCollected,
            collectedAmountVnd: collectedAmountVnd,
          ),
        );
    if (targetStatus == DeliveryStatus.delivered) {
      context.read<OrdersBloc>().add(
            const OnUpdateLastOrderStatusEvent(OrderRecord.statusDelivered),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DriverOrdersBloc, DriverOrdersState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TextCustom(state.error!, color: Colors.white),
              backgroundColor: ColorsFrave.errorColor,
            ),
          );
        } else if (state.isSuccess && state.successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TextCustom(state.successMessage!, color: Colors.white),
              backgroundColor: ColorsFrave.successColor,
            ),
          );
        }

        final match = state.assignedOrders.where((o) => o.id == widget.orderId);
        if (match.isNotEmpty) {
          setState(() {
            _order = match.first;
          });
        }
      },
      builder: (context, state) {
        final order = _order ??
            state.assignedOrders.firstWhere(
              (o) => o.id == widget.orderId,
              orElse: () => state.availableOrders.firstWhere(
                (o) => o.id == widget.orderId,
                orElse: () => OrderRecord(
                  id: widget.orderId,
                  clientId: '',
                  addressId: '',
                  street: '',
                  reference: '',
                  latitude: 0,
                  longitude: 0,
                  paymentMethod: 'CASH PAYMENT',
                  amount: 0,
                  status: OrderRecord.statusPaidOut,
                  products: const [],
                  createdAt: DateTime.now(),
                ),
              ),
            );

        final status = DeliveryStatus.fromString(order.status);
        final shortId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;
        final dateFormat = DateFormat('dd/MM/yyyy • HH:mm');
        final customerPhone = order.receiverPhone ?? '0901234567';

        return Scaffold(
          backgroundColor: ColorsFrave.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: TextCustom(
              'Chi tiết đơn hàng #$shortId',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.navigation, color: ColorsFrave.secondaryColor),
                tooltip: 'Mở bản đồ dẫn đường trực tiếp',
                onPressed: () {
                  context.read<OrdersBloc>().add(OnSetCurrentOrderEvent(order));
                  context.push('/delivery/map/${order.id}');
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step Progress Tracker
                _DeliveryStepTracker(currentStatus: status),

                // Cash settlement — the money the courier took at the door.
                if (order.cashCollected) ...[
                  const SizedBox(height: 16),
                  CodSettlementBadge(order: order),
                ],

                const SizedBox(height: 16),

                // Customer Contact Card (Call & SMS)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: ColorsFrave.primaryColor.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.person,
                          color: ColorsFrave.primaryColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextCustom(
                              order.receiverName ?? 'Khách hàng',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            const SizedBox(height: 2),
                            TextCustom(
                              customerPhone,
                              color: ColorsFrave.greyText,
                              fontSize: 13,
                            ),
                          ],
                        ),
                      ),
                      // Call button
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: ColorsFrave.successColor.withValues(alpha: 0.15),
                        ),
                        icon: const Icon(Icons.phone, color: ColorsFrave.successColor),
                        tooltip: 'Gọi khách hàng',
                        onPressed: () => _makePhoneCall(customerPhone),
                      ),
                      const SizedBox(width: 8),
                      // SMS button
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: ColorsFrave.primaryColor.withValues(alpha: 0.15),
                        ),
                        icon: const Icon(Icons.message, color: ColorsFrave.primaryColor),
                        tooltip: 'Gửi tin nhắn SMS',
                        onPressed: () => _sendSms(customerPhone),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Delivery Destination & Navigation Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const TextCustom(
                            'Địa chỉ giao hàng',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          InkWell(
                            onTap: () {
                              context.read<OrdersBloc>().add(OnSetCurrentOrderEvent(order));
                              context.push('/delivery/map/${order.id}');
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.map, size: 16, color: ColorsFrave.primaryColor),
                                SizedBox(width: 4),
                                TextCustom(
                                  'Bản đồ',
                                  color: ColorsFrave.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: ColorsFrave.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextCustom(
                                  order.street.isNotEmpty ? order.street : 'Chưa xác định địa chỉ',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                if (order.reference.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  TextCustom(
                                    'Ghi chú: ${order.reference}',
                                    color: ColorsFrave.greyText,
                                    fontSize: 13,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextCustom(
                        'Thời gian đặt: ${dateFormat.format(order.createdAt)}',
                        color: ColorsFrave.greyText,
                        fontSize: 12,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Proof Photo Card (if uploaded)
                if (order.deliveryPhoto != null && order.deliveryPhoto!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TextCustom(
                          'Ảnh xác nhận giao hàng',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 180,
                            child: ImageResolver.resolveWidget(
                              order.deliveryPhoto!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Order Items Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TextCustom(
                        'Danh sách món ăn',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      const SizedBox(height: 12),
                      ...order.products.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: ImageResolver.resolveWidget(
                                    p.picture,
                                    width: 44,
                                    height: 44,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextCustom(
                                      p.nameProduct,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    TextCustom(
                                      '${p.quantity} x ${Money.format(p.price)}',
                                      color: ColorsFrave.greyText,
                                      fontSize: 12,
                                    ),
                                  ],
                                ),
                              ),
                              TextCustom(
                                Money.format(p.quantity * p.price),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const TextCustom(
                            'Phương thức thanh toán',
                            color: ColorsFrave.greyText,
                            fontSize: 13,
                          ),
                          TextCustom(
                            order.paymentMethod,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const TextCustom(
                            'Tổng tiền thu (COD)',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          TextCustom(
                            Money.format(order.codAmountVnd),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: ColorsFrave.primaryColor,
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: ColorsFrave.successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ColorsFrave.successColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 18,
                                  color: ColorsFrave.successColor,
                                ),
                                SizedBox(width: 8),
                                TextCustom(
                                  'Phần tiền nhận được',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: ColorsFrave.successColor,
                                ),
                              ],
                            ),
                            TextCustom(
                              Money.format(DriverEarnings.earningsVndForOrder(order)),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: ColorsFrave.successColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // State Machine Action Buttons
                if (_isUploadingPhoto)
                  const Center(
                    child: CircularProgressIndicator(color: ColorsFrave.primaryColor),
                  )
                else
                  StatusActionButtons(
                    currentStatus: status,
                    isLoading: state.isLoading,
                    onTransition: (target) {
                      _transitionStatus(order, target, null);
                    },
                    onUploadDeliveryPhoto: () {
                      _handleUploadDeliveryProof(order);
                    },
                    onReject: status == DeliveryStatus.pending
                        ? () => _confirmReject(order)
                        : null,
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeliveryStepTracker extends StatelessWidget {
  final DeliveryStatus currentStatus;

  const _DeliveryStepTracker({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'status': DeliveryStatus.accepted, 'label': 'Đã nhận đơn'},
      {'status': DeliveryStatus.pickedUp, 'label': 'Đã lấy hàng'},
      {'status': DeliveryStatus.onTheWay, 'label': 'Đang giao'},
      {'status': DeliveryStatus.delivered, 'label': 'Đã giao'},
    ];

    int currentIndex = -1;
    switch (currentStatus) {
      case DeliveryStatus.pending:
        currentIndex = -1;
        break;
      case DeliveryStatus.preparing:
        // The kitchen has the order but no courier yet — same "before the
        // driver" position as [DeliveryStatus.pending].
        currentIndex = -1;
        break;
      case DeliveryStatus.accepted:
        currentIndex = 0;
        break;
      case DeliveryStatus.pickedUp:
        currentIndex = 1;
        break;
      case DeliveryStatus.onTheWay:
        currentIndex = 2;
        break;
      case DeliveryStatus.delivered:
        currentIndex = 3;
        break;
      case DeliveryStatus.cancelled:
        currentIndex = -2;
        break;
    }

    if (currentIndex == -2) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColorsFrave.errorColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: ColorsFrave.errorColor, size: 20),
            SizedBox(width: 8),
            TextCustom(
              'Đơn hàng đã hủy',
              color: ColorsFrave.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(steps.length, (index) {
          final isDone = currentIndex >= index;
          final isCurrent = currentIndex == index;

          return Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? ColorsFrave.primaryColor
                      : Colors.grey.shade200,
                  border: isCurrent
                      ? Border.all(color: ColorsFrave.primaryColor, width: 2)
                      : null,
                ),
                child: Icon(
                  isDone ? Icons.check : Icons.circle,
                  color: isDone ? Colors.white : Colors.grey.shade400,
                  size: 16,
                ),
              ),
              const SizedBox(height: 6),
              TextCustom(
                steps[index]['label'] as String,
                fontSize: 11,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isDone ? ColorsFrave.primaryColor : ColorsFrave.greyText,
              ),
            ],
          );
        }),
      ),
    );
  }
}
