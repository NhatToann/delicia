import 'package:flutter/material.dart';

import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The "Pay Now" pill (Figma node `202:3509`).
///
/// 157.43 x 38, radius 38, fill `#FFDECF`, label League Spartan Regular
/// 23.07 in `#E95322` with a `-0.1154` tracking.
class PayNowButton extends StatelessWidget {
  const PayNowButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.busy = false,
  });

  /// Fired when the button is tapped.
  final VoidCallback? onPressed;

  /// Whether the button reacts to taps.
  final bool enabled;

  /// Whether a payment is in flight — the label then reads "Processing…".
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !busy;
    final buttonWidth = (MediaQuery.sizeOf(context).width - 48)
        .clamp(0.0, 360.0);
    return Semantics(
      container: true,
      button: true,
      enabled: active,
      label: context.l10n.actionPayNow,
      child: SizedBox(
        width: buttonWidth,
        height: 52,
        child: Material(
          color: active ? ColorsFrave.orangeSoft : ColorsFrave.surfaceVariant,
          borderRadius: BorderRadius.circular(38),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: active ? onPressed : null,
            child: Center(
              child: ExcludeSemantics(
                // Figma's label sits 10.857 px below the pill's top edge, so
                // it lands a pixel lower than a plain centred box would.
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    busy ? context.l10n.processing : context.l10n.actionPayNow,
                    maxLines: 1,
                    style: FraveText.regular(
                      18,
                      color: active
                          ? ColorsFrave.navOrange
                          : ColorsFrave.lightGrey,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
