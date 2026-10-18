import 'package:flutter/material.dart';

import '../../../../domain/models/product.dart';
import '../../../components/text_custom.dart';
import '../../../helpers/image_resolver.dart';
import '../../../themes/colors_frave.dart';

/// Card showing a single product (image + name + price).
///
/// The card uses a [LayoutBuilder] to derive the image height from the
/// actual cell width instead of an `AspectRatio` + `childAspectRatio`
/// pair. This avoids the "bottom overflow" that happens when the
/// 2-line name text plus price row push past the cell's natural
/// height. Everything else is sized relative to the column height.
class ProductCard extends StatelessWidget {
  final Productsdb product;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The image takes 60% of the cell height, leaving comfortable
          // room for the 2-line name + price even on the smallest
          // devices.
          final imageHeight = constraints.maxHeight * 0.6;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
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
                const SizedBox(height: 8),
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
    );
  }
}
