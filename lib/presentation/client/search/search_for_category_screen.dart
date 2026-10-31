import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/products/products_bloc.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product.dart';
import '../../components/app_bottom_nav.dart';
import '../../components/app_nav_destination.dart';
import '../../helpers/category_assets.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import '../cart/cart_screen.dart';
import '../home/widgets/profile_menu.dart';

/// Discover tab styled after Figma 5.1-A. Home filters pass their selected
/// category through the route so Discover opens already scoped to that group.
class SearchForCategoryScreen extends StatefulWidget {
  final Category? category;

  const SearchForCategoryScreen({super.key, this.category});

  @override
  State<SearchForCategoryScreen> createState() =>
      _SearchForCategoryScreenState();
}

enum _DiscoverSort { popular, priceLow, priceHigh, rating }

class _SearchForCategoryScreenState extends State<SearchForCategoryScreen> {
  final TextEditingController _controller = TextEditingController();
  _DiscoverSort _sort = _DiscoverSort.popular;
  bool _discountOnly = false;
  double _minimumRating = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProductsBloc>()
        ..add(const OnGetCategoriesEvent())
        ..add(
          OnStartSearchEvent(
            categoryId: widget.category?.id ?? 'cat_burger',
            categoryName:
                widget.category?.category ?? context.l10n.categorySnacks,
          ),
        );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectCategory(Category? category, ProductsState state) {
    final bloc = context.read<ProductsBloc>();
    if (category == null || category.id == state.selectedCategoryId) {
      bloc.add(const OnClearCategoryEvent());
    } else {
      bloc.add(
        OnSelectCategoryEvent(
          idCategory: category.id,
          category: category.category,
        ),
      );
    }
  }

  List<Productsdb> _visibleProducts(ProductsState state) {
    final products = state.searchResults.where((product) {
      if (_discountOnly && product.discountPercent == null) return false;
      if (product.rating < _minimumRating) return false;
      return true;
    }).toList();
    products.sort((a, b) {
      switch (_sort) {
        case _DiscoverSort.priceLow:
          return a.price.compareTo(b.price);
        case _DiscoverSort.priceHigh:
          return b.price.compareTo(a.price);
        case _DiscoverSort.rating:
          final rating = b.rating.compareTo(a.rating);
          return rating != 0 ? rating : b.sold.compareTo(a.sold);
        case _DiscoverSort.popular:
          final popularity = b.sold.compareTo(a.sold);
          return popularity != 0 ? popularity : b.rating.compareTo(a.rating);
      }
    });
    return products;
  }

  Future<void> _showSortSheet() async {
    final selected = await showModalBottomSheet<_DiscoverSort>(
      context: context,
      backgroundColor: ColorsFrave.surfaceColor,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                context.l10n.discoverSortTitle,
                style: FraveText.bold(20, color: ColorsFrave.ink),
              ),
            ),
            for (final option in _DiscoverSort.values)
              ListTile(
                leading: Icon(
                  _sort == option
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _sort == option
                      ? ColorsFrave.navOrange
                      : ColorsFrave.greyText,
                ),
                title: Text(_sortLabel(context, option)),
                onTap: () => Navigator.pop(sheetContext, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _sort = selected);
  }

  Future<void> _showFilterSheet() async {
    var discountOnly = _discountOnly;
    var minimumRating = _minimumRating;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ColorsFrave.surfaceColor,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.discoverFilterTitle,
                  style: FraveText.bold(20, color: ColorsFrave.ink),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: ColorsFrave.navOrange,
                  title: Text(context.l10n.discoverDiscountOnly),
                  value: discountOnly,
                  onChanged: (value) =>
                      setSheetState(() => discountOnly = value),
                ),
                Text(
                  context.l10n.discoverMinimumRating,
                  style: FraveText.medium(15, color: ColorsFrave.ink),
                ),
                Slider(
                  value: minimumRating,
                  min: 0,
                  max: 5,
                  divisions: 5,
                  activeColor: ColorsFrave.navOrange,
                  label: minimumRating == 0
                      ? context.l10n.discoverAnyRating
                      : minimumRating.toStringAsFixed(1),
                  onChanged: (value) =>
                      setSheetState(() => minimumRating = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ColorsFrave.navOrange,
                    ),
                    onPressed: () {
                      setState(() {
                        _discountOnly = discountOnly;
                        _minimumRating = minimumRating;
                      });
                      Navigator.pop(sheetContext);
                    },
                    child: Text(context.l10n.actionApply),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sortLabel(BuildContext context, _DiscoverSort sort) {
    final l10n = context.l10n;
    return switch (sort) {
      _DiscoverSort.popular => l10n.discoverPopular,
      _DiscoverSort.priceLow => l10n.discoverPriceLowToHigh,
      _DiscoverSort.priceHigh => l10n.discoverPriceHighToLow,
      _DiscoverSort.rating => l10n.discoverTopRated,
    };
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      body: SafeArea(
        top: false,
        child: BlocBuilder<ProductsBloc, ProductsState>(
          builder: (context, state) {
            final products = _visibleProducts(state);
            final categories = state.categories;
            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: _DiscoverHeader(
                    topInset: topInset,
                    controller: _controller,
                    onSearch: (value) => context.read<ProductsBloc>().add(
                      OnSearchProductEvent(value),
                    ),
                    onClear: () {
                      _controller.clear();
                      context.read<ProductsBloc>().add(
                        const OnClearSearchEvent(),
                      );
                    },
                    onFilter: _showFilterSheet,
                    onCart: _openCart,
                    onNotifications: () => context.push('/client/orders'),
                    onProfile: _openProfile,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DiscoverCategoryRail(
                    categories: categories,
                    selectedCategoryId: state.selectedCategoryId,
                    onSelected: (category) => _selectCategory(category, state),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: ColorsFrave.pageBg,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.discoverSortBy,
                          style: FraveText.regular(
                            13,
                            color: ColorsFrave.greyText,
                          ),
                        ),
                        const SizedBox(width: 5),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _showSortSheet,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 4,
                            ),
                            child: Text(
                              _sortLabel(context, _sort),
                              style: FraveText.semiBold(
                                13,
                                color: ColorsFrave.navOrange,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: context.l10n.discoverFilterTitle,
                          child: Tooltip(
                            message: context.l10n.discoverFilterTitle,
                            child: Material(
                              color: Colors.transparent,
                              child: InkResponse(
                                onTap: _showFilterSheet,
                                radius: 20,
                                containedInkWell: true,
                                customBorder: const CircleBorder(),
                                child: SvgPicture.asset(
                                  'assets/figma_home/filter_icon.svg',
                                  width: 20,
                                  height: 20,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.isLoadingSearch)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ColorsFrave.navOrange,
                      ),
                    ),
                  )
                else if (products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _DiscoverEmpty(
                      hasQuery: state.searchQuery.trim().isNotEmpty,
                      query: state.searchQuery,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(34, 0, 34, 20),
                    sliver: SliverList.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 22),
                      itemBuilder: (context, index) => _DiscoverProductCard(
                        product: products[index],
                        onTap: () => context.push(
                          '/client/details-product/${products[index].id}',
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: AppNavDestination.discover,
        onTap: (index) => AppNavDestination.go(context, index),
      ),
    );
  }

  void _openCart() {
    CartOverlay.show(
      context,
      onCheckout: () => context.push('/client/payment'),
    );
  }

  void _openProfile() {
    final ordersLabel = context.l10n.navOrders;
    final myProfileLabel = context.l10n.profileMyProfile;
    final addressLabel = context.l10n.profileDeliveryAddress;
    ProfileMenuOverlay.show(
      context,
      onItemTap: (label) {
        if (label == ordersLabel) {
          context.push('/client/orders');
        } else if (label == myProfileLabel) {
          context.push('/client/profile');
        } else if (label == addressLabel) {
          context.push('/client/profile/addresses');
        }
      },
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({
    required this.topInset,
    required this.controller,
    required this.onSearch,
    required this.onClear,
    required this.onFilter,
    required this.onCart,
    required this.onNotifications,
    required this.onProfile,
  });

  final double topInset;
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final VoidCallback onFilter;
  final VoidCallback onCart;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Container(
    color: ColorsFrave.headerYellow,
    padding: EdgeInsets.fromLTRB(36, topInset + 14, 36, 18),
    child: Row(
      children: [
        Flexible(
          child: SizedBox(
            height: 26,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              clipBehavior: Clip.antiAlias,
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                textAlign: TextAlign.center,
                onChanged: onSearch,
                style: FraveText.regular(12, color: ColorsFrave.ink),
                decoration: InputDecoration(
                  hintText: context.l10n.searchHint,
                  hintStyle: FraveText.light(12, color: ColorsFrave.greyText),
                  prefixIconConstraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 26,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 6),
                    child: SvgPicture.asset(
                      'assets/figma_home/search_icon.svg',
                      width: 12,
                      height: 12,
                    ),
                  ),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.l10n.actionClear,
                          onPressed: onClear,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 26,
                            height: 26,
                          ),
                          icon: const Icon(Icons.close, size: 13),
                        ),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _DiscoverHeaderIcon(
          asset: 'assets/figma_home/filter_icon.svg',
          size: 20,
          label: context.l10n.actionFilter,
          onTap: onFilter,
        ),
        const SizedBox(width: 5),
        _DiscoverHeaderIcon(
          asset: 'assets/figma_home/action_1.svg',
          size: 26,
          label: context.l10n.navCart,
          onTap: onCart,
        ),
        const SizedBox(width: 7),
        _DiscoverHeaderIcon(
          asset: 'assets/figma_home/action_2.svg',
          size: 26,
          label: context.l10n.homeNotifications,
          onTap: onNotifications,
        ),
        const SizedBox(width: 7),
        _DiscoverHeaderIcon(
          asset: 'assets/figma_home/action_3.svg',
          size: 26,
          label: context.l10n.profileMyProfile,
          onTap: onProfile,
        ),
      ],
    ),
  );
}

class _DiscoverHeaderIcon extends StatelessWidget {
  const _DiscoverHeaderIcon({
    required this.asset,
    required this.size,
    required this.label,
    required this.onTap,
  });

  final String asset;
  final double size;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: SvgPicture.asset(asset),
        ),
      ),
    ),
  );
}

class _DiscoverCategoryRail extends StatelessWidget {
  const _DiscoverCategoryRail({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String selectedCategoryId;
  final ValueChanged<Category?> onSelected;

  static const List<String> _preferredIds = [
    'cat_burger',
    'cat_pizza',
    'cat_healthy',
    'cat_dessert',
    'cat_drink',
    'c1',
    'c2',
    'c5',
    'c4',
    'c3',
  ];

  List<Category> _orderedCategories() {
    final ordered = <Category>[];
    for (final id in _preferredIds) {
      for (final category in categories) {
        if (category.id == id && !ordered.contains(category)) {
          ordered.add(category);
        }
      }
    }
    for (final category in categories) {
      if (!ordered.contains(category)) ordered.add(category);
    }
    return ordered;
  }

  String _label(BuildContext context, Category category) {
    return switch (category.id) {
      'cat_burger' || 'c1' => context.l10n.categorySnacks,
      'cat_pizza' || 'c2' => context.l10n.categoryMeal,
      'cat_healthy' || 'cat_asian' || 'c5' || 'c7' =>
        context.l10n.categoryVegan,
      'cat_dessert' || 'c4' => context.l10n.categoryDessert,
      'cat_drink' || 'c3' => context.l10n.categoryDrinks,
      _ => category.category,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _orderedCategories();
    return Container(
      color: ColorsFrave.navOrange,
      height: 104,
      padding: const EdgeInsets.only(top: 7, bottom: 5),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const SizedBox(width: 11),
        itemBuilder: (context, index) {
          final category = ordered[index];
          return _CategoryCircle(
            label: _label(context, category),
            iconAsset: CategoryAssets.iconFor(category),
            selected: selectedCategoryId == category.id,
            onTap: () => onSelected(category),
          );
        },
      ),
    );
  }
}

class _CategoryCircle extends StatelessWidget {
  const _CategoryCircle({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconAsset,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 60,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: selected ? ColorsFrave.pillYellow : Colors.white,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: ColorsFrave.ink, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: iconAsset == null
                ? Icon(icon, color: ColorsFrave.navOrange, size: 20)
                : SvgPicture.asset(
                    'assets/figma_home/$iconAsset',
                    width: 28,
                    height: 28,
                  ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FraveText.medium(10, color: Colors.white, height: 1),
          ),
        ],
      ),
    ),
  );
}

class _DiscoverProductCard extends StatelessWidget {
  const _DiscoverProductCard({required this.product, required this.onTap});

  final Productsdb product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageResolver.resolveWidget(
                  product.picture,
                  fit: BoxFit.cover,
                  fallback: CategoryAssets.photoFor(product),
                ),
                if (product.hasRating)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFFFB21C),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: FraveText.semiBold(11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    product.nameProduct,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FraveText.semiBold(15, color: ColorsFrave.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  Money.format(product.price),
                  style: FraveText.semiBold(15, color: ColorsFrave.navOrange),
                ),
              ],
            ),
          ),
          if (product.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                product.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FraveText.regular(12, color: ColorsFrave.greyText),
              ),
            ),
        ],
      ),
    ),
  );
}

class _DiscoverEmpty extends StatelessWidget {
  const _DiscoverEmpty({required this.hasQuery, required this.query});

  final bool hasQuery;
  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.restaurant_menu,
            size: 46,
            color: ColorsFrave.greyText,
          ),
          const SizedBox(height: 12),
          Text(
            hasQuery
                ? context.l10n.searchNoResults(query)
                : context.l10n.searchNoProducts,
            textAlign: TextAlign.center,
            style: FraveText.semiBold(16, color: ColorsFrave.ink),
          ),
        ],
      ),
    ),
  );
}
