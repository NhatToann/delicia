import 'package:flutter/material.dart';

import '../themes/colors_frave.dart';

Future<void> modalLoading(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: const Center(
        child: CircularProgressIndicator(color: ColorsFrave.primaryColor),
      ),
    ),
  );
}
