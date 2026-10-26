import 'package:flutter/material.dart';

import '../themes/colors_frave.dart';

Future<void> modalLoading(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      // The spinner must never trap the user: the hardware/gesture back
      // button has to be able to dismiss it.  `canPop: false` used to leave
      // an undismissable overlay on screen, which also blocked the back
      // button of the page underneath.
      canPop: true,
      child: const Center(
        child: CircularProgressIndicator(color: ColorsFrave.primaryColor),
      ),
    ),
  );
}
