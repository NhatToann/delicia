import 'package:flutter/material.dart';

import '../../../../domain/models/type_payment.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';
import 'payment_method_glyph.dart';

/// The localized name of a payment method.
///
/// The domain model carries the Figma copy (`CREDIT CARD`, `CASH PAYMENT`,
/// …) so the glyphs and the order records keep their canonical wording;
/// this maps that uid onto the Vietnamese label.
String paymentMethodLabel(AppLocalizations l10n, TypePaymentMethod method) {
  switch (method.uid) {
    case 'CREDIT_CARD':
      return l10n.paymentMethodCreditCard;
    case 'CASH':
      return l10n.paymentMethodCash;
    case 'PAYPAL':
      return l10n.paymentMethodPayPal;
    case 'GOOGLE_PAY':
      return l10n.paymentMethodGooglePay;
    case 'MERCADO_PAGO':
      return l10n.paymentMethodMercadoPago;
    case 'PAYOS':
      return l10n.paymentMethodPayOs;
    default:
      return method.type;
  }
}

/// The bottom sheet that lets the user pick a payment method.
///
/// Figma 4.3 - D only shows the *selected* method on the screen itself
/// (a row with the method name and a cream pill holding the masked card
/// number), with a peach "Edit" chip next to the section title. This sheet
/// is what that chip opens.
class PaymentMethodSheet extends StatelessWidget {
  const PaymentMethodSheet({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.methods,
  });

  /// The method currently in use.
  final TypePaymentMethod selected;

  /// Fired when the user picks a different method.
  final ValueChanged<TypePaymentMethod> onSelected;

  /// The methods offered to the user.
  final List<TypePaymentMethod> methods;

  /// Opens the sheet and returns the chosen method, or null if the user
  /// dismissed it.
  static Future<TypePaymentMethod?> show(
    BuildContext context, {
    required TypePaymentMethod selected,
    required List<TypePaymentMethod> methods,
  }) {
    return showModalBottomSheet<TypePaymentMethod>(
      context: context,
      backgroundColor: ColorsFrave.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => PaymentMethodSheet(
        selected: selected,
        methods: methods,
        onSelected: (m) => Navigator.of(context).pop(m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorsFrave.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.paymentMethod,
              style: FraveText.bold(
                22,
                color: ColorsFrave.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            ...methods.map((method) => _tile(context, method)),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, TypePaymentMethod method) {
    final isSelected = method.uid == selected.uid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? ColorsFrave.pillYellow : ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelected(method),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? ColorsFrave.navOrange
                    : ColorsFrave.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                PaymentMethodGlyph(
                  method: method,
                  width: 31,
                  height: 21.215,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    paymentMethodLabel(context.l10n, method),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FraveText.medium(
                      15,
                      color: ColorsFrave.ink,
                      height: 1.2,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: ColorsFrave.navOrange,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
