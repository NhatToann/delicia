import 'package:flutter/material.dart';

import '../../../../domain/models/product.dart';
import '../../../components/text_custom.dart';
import '../../../helpers/image_resolver.dart';
import '../../../themes/colors_frave.dart';

/// Card showing a single product (image + name + price).
///
/// Tapping the card invokes [onTap]. Image loading is delegated to
/// [ImageResolver] so the same widget can render local assets (the
/// current setup) or remote URLs (future migration to storage).
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
      child: Container(
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
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ImageResolver.resolveWidget(
                  product.picture,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextCustom(
              product.nameProduct,
              fontWeight: FontWeight.w600,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            TextCustom(
              '\$${product.price.toStringAsFixed(2)}',
              color: ColorsFrave.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
      ),
    );
  }
}
