import 'package:flutter/material.dart';

import '../components/btn_frave.dart';
import '../helpers/l10n_extension.dart';
import '../themes/colors_frave.dart';

/// Shows a centered success dialog with a checkmark.
/// Material Design 3 style.
Future<void> modalSuccess(
  BuildContext context,
  String message, {
  VoidCallback? onDone,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: ColorsFrave.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon with animation
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: ColorsFrave.successColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: ColorsFrave.successColor,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ColorsFrave.darkText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: BtnFrave(
                text: dialogContext.l10n.actionDone,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  if (onDone != null) onDone();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Centered warning dialog used for non-blocking errors.
/// Material Design 3 style.
Future<void> modalInfo(
  BuildContext context,
  String title,
  String message, {
  VoidCallback? onDone,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: ColorsFrave.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: ColorsFrave.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: ColorsFrave.errorColor,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ColorsFrave.darkText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: ColorsFrave.greyText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: BtnFrave(
                text: context.l10n.actionOk,
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  if (onDone != null) onDone();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
