import 'package:flutter/material.dart';

import '../../../../domain/models/delivery_user.dart';
import '../../../../domain/models/order_record.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The dialog that assigns a delivery driver to an order (UC-09).
///
/// The dialog shows every *enabled* driver — a disabled driver must not
/// receive new orders. The driver rows carry the number of orders they
/// are currently carrying, so the admin can spread the work.
class AssignDeliveryDialog extends StatelessWidget {
  const AssignDeliveryDialog({
    super.key,
    required this.order,
    required this.drivers,
    required this.onAssign,
    this.isSubmitting = false,
  });

  /// The order the driver will be assigned to.
  final OrderRecord order;

  /// Every known driver — the dialog filters the disabled ones out.
  final List<DeliveryUser> drivers;

  /// Fired with the chosen driver.
  final void Function(DeliveryUser driver) onAssign;

  /// True while the assignment is being written.
  final bool isSubmitting;

  /// Opens the dialog and returns the chosen driver, or `null`.
  static Future<DeliveryUser?> show(
    BuildContext context, {
    required OrderRecord order,
    required List<DeliveryUser> drivers,
    required void Function(DeliveryUser driver) onAssign,
    bool isSubmitting = false,
  }) {
    return showDialog<DeliveryUser>(
      context: context,
      builder: (dialogContext) => AssignDeliveryDialog(
        order: order,
        drivers: drivers,
        isSubmitting: isSubmitting,
        onAssign: (driver) {
          onAssign(driver);
          Navigator.of(dialogContext).pop(driver);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final available = drivers.where((d) => d.isEnabled).toList(growable: false);

    return AlertDialog(
      backgroundColor: ColorsFrave.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusFrave.card),
      ),
      title: Text(
        l10n.adminAssignDeliveryTitle,
        style: FraveText.semiBold(18, color: ColorsFrave.ink),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: available.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.delivery_dining_outlined,
                      size: 40,
                      color: ColorsFrave.navOrange,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.adminAssignDeliveryEmpty,
                      textAlign: TextAlign.center,
                      style: FraveText.regular(14, color: ColorsFrave.greyText),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: available.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  color: ColorsFrave.dividerOrange,
                ),
                itemBuilder: (context, index) {
                  final driver = available[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: ColorsFrave.orangeSoft,
                      child: Text(
                        _initial(driver.name),
                        style: FraveText.medium(
                          15,
                          color: ColorsFrave.navOrange,
                        ),
                      ),
                    ),
                    title: Text(
                      driver.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FraveText.medium(15, color: ColorsFrave.ink),
                    ),
                    subtitle: Text(
                      l10n.adminAssignDeliveryActiveOrders(driver.activeOrders),
                      style: FraveText.light(12, color: ColorsFrave.greyText),
                    ),
                    trailing: driver.phone.trim().isEmpty
                        ? null
                        : Text(
                            driver.phone,
                            style: FraveText.regular(13, color: ColorsFrave.greyText),
                          ),
                    onTap: isSubmitting ? null : () => onAssign(driver),
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.actionCancel,
            style: FraveText.medium(14, color: ColorsFrave.greyText),
          ),
        ),
      ],
    );
  }

  /// The first letter of the driver's name, used as the avatar.
  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }
}
