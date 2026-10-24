import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton placeholder used by screens while their data is loading.
///
/// Renders a stack of light/dark rectangles via [shimmer].  Pass any
/// child widget (typically an empty grid) for the layout — shimmer will
/// overlay it.
class ShimmerFrave extends StatelessWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerFrave({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE0E0E0),
    this.highlightColor = const Color(0xFFF5F5F5),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

/// Convenience helper that returns a square shimmer tile (used for the
/// product grid skeleton).
class ShimmerTile extends StatelessWidget {
  final double? width;
  final double? height;
  const ShimmerTile({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Two-column product skeleton used by [ClientHomeScreen] while
/// [ProductsState.isLoadingTopProducts] is `true`.
class ShimmerProductsGrid extends StatelessWidget {
  final int itemCount;
  const ShimmerProductsGrid({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ShimmerFrave(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.all(8),
          child: ShimmerTile(),
        ),
      ),
    );
  }
}

/// Horizontal pill skeleton used by [CategoryFilter] while
/// [ProductsState.isLoadingCategories] is `true`.
class ShimmerCategories extends StatelessWidget {
  const ShimmerCategories({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerFrave(
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.all(8),
            child: ShimmerTile(width: 80, height: 80),
          ),
        ),
      ),
    );
  }
}