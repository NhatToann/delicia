import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/product/product_bloc.dart';
import '../../../domain/models/product.dart';
import '../../../domain/services/admin_catalog_service.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';

/// AdminProductListScreen — the product management list (UC-08).
///
/// The screen carries a search field, a row of category filter chips and
/// the product rows themselves. The filters run client-side over the
/// catalogue the bloc already holds.
class AdminProductListScreen extends StatelessWidget {
  const AdminProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProductBloc>(
      create: (context) => ProductBloc(
        catalogService: context.read<AdminCatalogService>(),
        imageUploadService: context.read<ImageUploadService>(),
      )..add(const ProductLoadRequested()),
      child: const _AdminProductListView(),
    );
  }
}

class _AdminProductListView extends StatelessWidget {
  const _AdminProductListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      appBar: AppBar(
        backgroundColor: ColorsFrave.navOrange,
        foregroundColor: ColorsFrave.onOrange,
        elevation: 0,
        leading: IconButton(
          onPressed: () => goBack(context, fallback: '/admin/home'),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(
          context.l10n.adminProductsTitle,
          style: FraveText.semiBold(20, color: ColorsFrave.onOrange),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/admin/products/new'),
            icon: const Icon(Icons.add),
            tooltip: context.l10n.adminProductAdd,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const _ProductSearchField(),
          const _ProductCategoryChips(),
          Expanded(
            child: BlocConsumer<ProductBloc, ProductState>(
              listenWhen: (previous, current) =>
                  previous.error != current.error && current.error != null,
              listener: (context, state) {
                errorMessageSnack(context, state.error!);
              },
              builder: (context, state) {
                if (state.isLoading && state.products.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ColorsFrave.navOrange,
                    ),
                  );
                }
                final products = state.visibleProducts;
                if (products.isEmpty) {
                  return const _ProductEmpty();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _ProductTile(product: products[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The search field above the list.
class _ProductSearchField extends StatelessWidget {
  const _ProductSearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorsFrave.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        onChanged: (value) =>
            context.read<ProductBloc>().add(ProductSearchChanged(value)),
        textInputAction: TextInputAction.search,
        style: FraveText.regular(14, color: ColorsFrave.ink),
        decoration: InputDecoration(
          hintText: context.l10n.adminProductSearchHint,
          hintStyle: FraveText.regular(14, color: ColorsFrave.greyText),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: ColorsFrave.greyText,
          ),
          filled: true,
          fillColor: ColorsFrave.pageBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusFrave.field),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusFrave.field),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusFrave.field),
            borderSide: const BorderSide(color: ColorsFrave.navOrange, width: 1),
          ),
        ),
      ),
    );
  }
}

/// The row of category filter chips.
class _ProductCategoryChips extends StatelessWidget {
  const _ProductCategoryChips();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductBloc>().state;
    final categories = state.categories;

    return Container(
      color: ColorsFrave.surfaceColor,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: <Widget>[
            _CategoryChip(
              label: context.l10n.adminProductAllCategories,
              isSelected: state.categoryId.isEmpty,
              onTap: () => context
                  .read<ProductBloc>()
                  .add(const ProductCategoryFilterChanged('')),
            ),
            for (final category in categories)
              _CategoryChip(
                label: category.category,
                isSelected: state.categoryId == category.id,
                onTap: () => context
                    .read<ProductBloc>()
                    .add(ProductCategoryFilterChanged(category.id)),
              ),
          ],
        ),
      ),
    );
  }
}

/// One filter chip.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? ColorsFrave.navOrange : ColorsFrave.orangeSoft,
        borderRadius: BorderRadius.circular(100),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 32,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    label,
                    maxLines: 1,
                    style: isSelected
                        ? FraveText.medium(13, color: ColorsFrave.onOrange)
                        : FraveText.regular(13, color: ColorsFrave.navOrange),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One product row.
class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Productsdb product;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 60,
              height: 60,
              child: product.picture.trim().isEmpty
                  ? Container(
                      color: ColorsFrave.orangeSoft,
                      child: const Icon(
                        Icons.fastfood,
                        color: ColorsFrave.navOrange,
                      ),
                    )
                  : ImageResolver.resolveWidget(
                      product.picture,
                      fit: BoxFit.cover,
                      fallback: 'assets/icons/no-data.svg',
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product.nameProduct,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.medium(16, color: ColorsFrave.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  product.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.light(13, color: ColorsFrave.greyText),
                ),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    Text(
                      Money.format(product.price),
                      style: FraveText.medium(15, color: ColorsFrave.navOrange),
                    ),
                    const SizedBox(width: 8),
                    _StockPill(isActive: product.isActive),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                context.push('/admin/products/${product.id}');
                return;
              }
              if (value == 'toggle') {
                context.read<ProductBloc>().add(
                      ProductStatusChanged(
                        product: product,
                        status: product.isActive ? 0 : 1,
                      ),
                    );
                return;
              }
              _confirmDelete(context);
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Text(
                  l10n.actionEdit,
                  style: FraveText.regular(14, color: ColorsFrave.ink),
                ),
              ),
              PopupMenuItem<String>(
                value: 'toggle',
                child: Text(
                  product.isActive ? l10n.adminProductSoldOut : l10n.adminProductInStock,
                  style: FraveText.regular(14, color: ColorsFrave.ink),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  l10n.actionDelete,
                  style: FraveText.regular(14, color: ColorsFrave.errorColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<ProductBloc>();
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsFrave.surfaceColor,
        title: Text(
          l10n.adminProductDeleteTitle,
          style: FraveText.semiBold(18, color: ColorsFrave.ink),
        ),
        content: Text(
          l10n.adminProductDeleteMessage(product.nameProduct),
          style: FraveText.regular(14, color: ColorsFrave.greyText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.actionCancel,
              style: FraveText.medium(14, color: ColorsFrave.greyText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.actionDelete,
              style: FraveText.medium(14, color: ColorsFrave.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    bloc.add(ProductDeleteRequested(product.id));
  }
}

/// The "in stock / sold out" pill.
class _StockPill extends StatelessWidget {
  const _StockPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? ColorsFrave.successColor : ColorsFrave.greyText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        isActive
            ? context.l10n.adminProductInStock
            : context.l10n.adminProductSoldOut,
        style: FraveText.medium(11, color: color),
      ),
    );
  }
}

/// The empty state of the product list.
class _ProductEmpty extends StatelessWidget {
  const _ProductEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.fastfood_outlined,
              size: 56,
              color: ColorsFrave.navOrange,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.adminProductsEmpty,
              textAlign: TextAlign.center,
              style: FraveText.regular(15, color: ColorsFrave.greyText),
            ),
          ],
        ),
      ),
    );
  }
}
