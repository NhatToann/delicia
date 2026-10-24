import 'package:flutter/material.dart';

import '../components/btn_frave.dart';
import '../components/text_custom.dart';
import '../themes/colors_frave.dart';

/// Shows a centered success dialog with a checkmark. Closes itself when
/// the user taps the "Done" button — the optional [onDone] runs first.
Future<void> modalSuccess(
  BuildContext context,
  String message, {
  VoidCallback? onDone,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: ColorsFrave.successColor,
              size: 80,
            ),
            const SizedBox(height: 12),
            TextCustom(
              message,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            BtnFrave(
              text: 'Done',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                if (onDone != null) onDone();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Centered warning dialog used for non-blocking errors.
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: ColorsFrave.errorColor,
              size: 80,
            ),
            const SizedBox(height: 12),
            TextCustom(
              title,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextCustom(
              message,
              textAlign: TextAlign.center,
              color: ColorsFrave.greyText,
            ),
            const SizedBox(height: 20),
            BtnFrave(
              text: 'OK',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                if (onDone != null) onDone();
              },
            ),
          ],
        ),
      ),
    ),
  );
}