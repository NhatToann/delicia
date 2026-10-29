import 'package:flutter/material.dart';

import '../../../../domain/models/category.dart';
import '../../../helpers/image_resolver.dart';
import '../../../themes/colors_frave.dart';

/// Horizontal scroll of categories shown on the client home screen.
/// Material Design 3 style following UI Kit guidelines.
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
      return const SizedBox(height: 120);
    }
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = categories[i];
          final isSelected = selectedCategoryId == c.id;
          return _CategoryItem(
            category: c,
            isSelected: isSelected,
            onTap: () => onSelected(c),
          );
        },
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 95,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? ColorsFrave.primaryColor : ColorsFrave.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ColorsFrave.primaryColor : ColorsFrave.surfaceVariant,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: ColorsFrave.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? ColorsFrave.onPrimary.withValues(alpha: 0.2)
                    : ColorsFrave.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: ImageResolver.resolveWidget(
                  category.picture,
                  fit: BoxFit.cover,
                  fallback: 'assets/icons/no-data.svg',
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Category Name
            Text(
              category.category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? ColorsFrave.onPrimary : ColorsFrave.darkText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
