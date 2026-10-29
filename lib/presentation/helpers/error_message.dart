import 'package:flutter/material.dart';

import '../../domain/services/app_failure.dart';
import 'error_localizer.dart';
import 'l10n_extension.dart';

/// Shows a failure as a red snack bar.
///
/// The [failure] carries a stable code; the sentence is looked up in the
/// Vietnamese translation table so the wording lives in exactly one place.
void errorMessageSnack(BuildContext context, AppFailure failure) {
  _show(context, localizeFailure(context.l10n, failure));
}

/// Shows an already-translated message as a red snack bar.
///
/// Use this for copy that is written directly in the widget layer (e.g. a
/// form-validation sentence) rather than for a domain failure.
void errorTextSnack(BuildContext context, String message) {
  _show(context, message);
}

void _show(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
}
