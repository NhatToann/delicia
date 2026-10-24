import 'package:flutter/material.dart';

import '../../../../domain/models/product.dart';
import '../../../components/text_custom.dart';
import '../../../helpers/image_resolver.dart';
import '../../../themes/colors_frave.dart';

/// Card showing a single product (image + name + price).
///
/// Layout strategy (avoids the "bottom overflow" that happens when
/// an `AspectRatio` image plus a 2-line name plus a price row
/// exceed the cell's natural height):
///
///   * The card is wrapped in a [LayoutBuilder] so it knows the
///     cell's actual width AND height.
///   * The image takes a fixed percentage of the cell height
///     (60%) — derived from the constraints, not from an
///     AspectRatio that would over-allocate space.
///   * The text block fills the remaining vertical space via
///     [Expanded] + [MainAxisAlignment.spaceBetween], so the
///     price row always sits at the bottom inside the cell.
class ProductCard extends StatelessWidget {
  final Productsdb product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  static const double _imageFraction = 0.6;
  static const double _cardPadding = 8;
  static const double _imageGap = 8;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight =
                  constraints.maxHeight - _cardPadding * 2;
              final imageHeight =
                  (availableHeight * _imageFraction).clamp(0.0, 240.0);
              return Padding(
                padding: const EdgeInsets.all(_cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ImageResolver.resolveWidget(
                          product.picture,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: _imageGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextCustom(
                            product.nameProduct,
                            fontWeight: FontWeight.w600,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          TextCustom(
                            '\$${product.price.toStringAsFixed(2)}',
                            color: ColorsFrave.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
