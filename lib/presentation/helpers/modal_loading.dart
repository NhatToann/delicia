import 'package:flutter/material.dart';

import '../helpers/l10n_extension.dart';
import '../themes/colors_frave.dart';

/// Material Design 3 Loading Modal
Future<void> modalLoading(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: ColorsFrave.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    ColorsFrave.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.loadingGeneric,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ColorsFrave.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
