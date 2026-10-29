import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../domain/models/type_payment.dart';

/// The glyph that identifies a payment method.
///
/// Figma node `286:1862` is the "Card icon" — a 31 x 21.215 node whose
/// artwork bleeds 3.61 % horizontally and 5.28 % vertically, so the SVG it
/// exports is 33.2392 x 23.4538. The card method therefore uses the
/// bundled asset at its bleeding size, and every other method falls back
/// to the Material icon the domain model carries.
class PaymentMethodGlyph extends StatelessWidget {
  const PaymentMethodGlyph({
    super.key,
    required this.method,
    this.width = 33.2392,
    this.height = 23.4538,
  });

  /// The method to draw.
  final TypePaymentMethod method;

  /// Width of the artwork.
  final double width;

  /// Height of the artwork.
  final double height;

  @override
  Widget build(BuildContext context) {
    final asset = method.asset;
    if (asset != null) {
      return SizedBox(
        width: width,
        height: height,
        child: SvgPicture.asset(asset, fit: BoxFit.fill),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: Alignment.center,
        child: Icon(method.icon, color: method.color, size: height * 0.9),
      ),
    );
  }
}
