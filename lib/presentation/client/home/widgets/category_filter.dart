import 'package:flutter/material.dart';

import '../../../../domain/models/category.dart';
import '../../../components/text_custom.dart';
import '../../../helpers/image_resolver.dart';
import '../../../themes/colors_frave.dart';

/// Horizontal scroll of categories shown on the client home screen.
///
/// Tapping a category invokes [onSelected] (used to push the
/// `SearchForCategoryScreen`). The currently selected category is
/// visually highlighted — the bloc resets the selection when the screen
/// pops.
class CategoryFilter extends StatelessWidget {
  final List<Category> categories;
  final String selectedCategoryId;
  final ValueChanged<Category> onSelected;

  const CategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox(height: 100);
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = categories[i];
          final isSelected = selectedCategoryId == c.id;
          return GestureDetector(
            onTap: () => onSelected(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 88,
              decoration: BoxDecoration(
                color: isSelected ? ColorsFrave.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? ColorsFrave.primaryColor
                      : ColorsFrave.backgroundColor,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: ColorsFrave.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ImageResolver.resolveWidget(
                      c.picture,
                      fit: BoxFit.cover,
                      fallback: 'assets/icons/no-data.svg',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TextCustom(
                      c.category,
                      fontSize: 12,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      color: isSelected ? Colors.white : ColorsFrave.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
