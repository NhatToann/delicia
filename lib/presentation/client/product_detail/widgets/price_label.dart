import 'package:flutter/material.dart';

import '../../../../domain/models/product.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The price of a product, rendered the way the catalogue wants it.
///
/// A row can parse perfectly well and still carry no price — that is what
/// happened to the live catalogue in October 2026, when a `PATCH` wiped
/// every field except the translated ones. The price then fell back to
/// `0.0` and the whole app showed "0 ₫", which reads like a free dish
/// rather than a broken row.
///
/// This widget tells the two apart: a real price is formatted through
/// [Money.format], a missing one shows the "giá không xác định" label
/// instead of a misleading zero.
class PriceLabel extends StatelessWidget {
  const PriceLabel({
    super.key,
    required this.product,
    this.size = 15,
    this.color = ColorsFrave.navOrange,
    this.weight,
    this.height = 1.1,
  });

  /// The product whose price is shown.
  final Productsdb product;

  /// Font size of the price.
  final double size;

  /// Colour of the price.
  final Color color;

  /// Font weight of the price. Defaults to bold for the big price.
  final FontWeight? weight;

  /// Line height of the price.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!product.hasPrice) {
      return Text(
        context.l10n.productDetailPriceUnavailable,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: FraveText.medium(
          size,
          color: ColorsFrave.lightGrey,
          height: height,
        ),
      );
    }

    return Text(
      Money.format(product.price),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: FraveText.regular(
        size,
        color: color,
        height: height,
      ).copyWith(fontWeight: weight ?? FontWeight.w700),
    );
  }
}
