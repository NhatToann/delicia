import 'package:flutter/material.dart';

import '../../../../domain/models/delivery_status.dart';
import '../../../components/btn_frave.dart';
import '../../../components/text_custom.dart';
import '../../../themes/colors_frave.dart';

class StatusActionButtons extends StatelessWidget {
  final DeliveryStatus currentStatus;
  final bool isLoading;
  final ValueChanged<DeliveryStatus> onTransition;
  final VoidCallback onUploadDeliveryPhoto;
  final VoidCallback? onReject;

  const StatusActionButtons({
    super.key,
    required this.currentStatus,
    required this.isLoading,
    required this.onTransition,
    required this.onUploadDeliveryPhoto,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (currentStatus == DeliveryStatus.delivered) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ColorsFrave.successColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorsFrave.successColor.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: ColorsFrave.successColor, size: 24),
            SizedBox(width: 8),
            TextCustom(
              'Đơn hàng đã giao thành công',
              color: ColorsFrave.successColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ],
        ),
      );
    }

    if (currentStatus == DeliveryStatus.cancelled) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ColorsFrave.errorColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorsFrave.errorColor.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: ColorsFrave.errorColor, size: 24),
            SizedBox(width: 8),
            TextCustom(
              'Đơn hàng đã bị hủy',
              color: ColorsFrave.errorColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ],
        ),
      );
    }

    // Happy-path next step
    final next = currentStatus.nextStep;

    if (currentStatus == DeliveryStatus.pending) {
      return Row(
        children: [
          if (onReject != null) ...[
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ColorsFrave.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isLoading ? null : onReject,
                child: const TextCustom(
                  'Từ chối',
                  color: ColorsFrave.errorColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: BtnFrave(
              text: 'Nhận đơn',
              color: ColorsFrave.primaryColor,
              onPressed: isLoading
                  ? null
                  : () {
                      if (next != null) onTransition(next);
                    },
            ),
          ),
        ],
      );
    }

    String buttonText = 'Cập nhật trạng thái';
    Color buttonColor = ColorsFrave.primaryColor;
    switch (currentStatus) {
      case DeliveryStatus.pending:
        buttonText = 'Nhận đơn';
        buttonColor = ColorsFrave.primaryColor;
        break;
      case DeliveryStatus.accepted:
        buttonText = 'Xác nhận đã lấy hàng tại quán';
        buttonColor = Colors.indigo;
        break;
      case DeliveryStatus.pickedUp:
        buttonText = 'Bắt đầu giao hàng (Đang di chuyển)';
        buttonColor = Colors.amber.shade900;
        break;
      case DeliveryStatus.onTheWay:
        buttonText = 'Hoàn thành giao hàng (Chụp ảnh xác nhận)';
        buttonColor = ColorsFrave.successColor;
        break;
      default:
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null)
          BtnFrave(
            text: buttonText,
            color: buttonColor,
            onPressed: isLoading
                ? null
                : () {
                    if (currentStatus == DeliveryStatus.onTheWay) {
                      // Trigger photo upload dialog before completing delivery
                      onUploadDeliveryPhoto();
                    } else {
                      onTransition(next);
                    }
                  },
          ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.cancel_outlined, size: 16, color: ColorsFrave.errorColor),
            label: const TextCustom(
              'Hủy giao hàng / Báo sự cố',
              color: ColorsFrave.errorColor,
              fontSize: 13,
            ),
            onPressed: isLoading
                ? null
                : () => _confirmCancel(context),
          ),
        ),
      ],
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const TextCustom('Hủy giao hàng', fontWeight: FontWeight.bold),
        content: const TextCustom(
          'Bạn có chắc chắn muốn hủy giao đơn hàng này không?',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TextCustom('Không, tiếp tục giao', color: ColorsFrave.greyText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onTransition(DeliveryStatus.cancelled);
            },
            child: const TextCustom('Đồng ý hủy', color: Colors.white),
          ),
        ],
      ),
    );
  }
}
