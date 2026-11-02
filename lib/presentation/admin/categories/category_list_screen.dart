import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/category/category_bloc.dart';
import '../../../domain/models/category.dart';
import '../../../domain/services/admin_catalog_service.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';

/// AdminCategoryListScreen — the category management list (UC-08).
///
/// The list carries a search field (the filter runs client-side), a
/// "add" button in the app bar and a row action menu with edit / delete.
class AdminCategoryListScreen extends StatelessWidget {
  const AdminCategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CategoryBloc>(
      create: (context) => CategoryBloc(
        catalogService: context.read<AdminCatalogService>(),
        imageUploadService: context.read<ImageUploadService>(),
      )..add(const CategoryLoadRequested()),
      child: const _AdminCategoryListView(),
    );
  }
}

class _AdminCategoryListView extends StatelessWidget {
  const _AdminCategoryListView();

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
          context.l10n.adminCategoriesTitle,
          style: FraveText.semiBold(20, color: ColorsFrave.onOrange),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/admin/categories/new'),
            icon: const Icon(Icons.add),
            tooltip: context.l10n.adminCategoryAdd,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const _CategorySearchField(),
          Expanded(
            child: BlocConsumer<CategoryBloc, CategoryState>(
              listenWhen: (previous, current) =>
                  previous.error != current.error && current.error != null,
              listener: (context, state) {
                errorMessageSnack(context, state.error!);
              },
              builder: (context, state) {
                if (state.isLoading && state.categories.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ColorsFrave.navOrange,
                    ),
                  );
                }
                final categories = state.visibleCategories;
                if (categories.isEmpty) {
                  return _CategoryEmpty(hasQuery: state.query.isNotEmpty);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _CategoryTile(category: categories[index]),
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
class _CategorySearchField extends StatelessWidget {
  const _CategorySearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorsFrave.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        onChanged: (value) =>
            context.read<CategoryBloc>().add(CategorySearchChanged(value)),
        textInputAction: TextInputAction.search,
        style: FraveText.regular(14, color: ColorsFrave.ink),
        decoration: InputDecoration(
          hintText: context.l10n.adminCategorySearchHint,
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

/// One category row.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
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
              width: 56,
              height: 56,
              child: category.picture.trim().isEmpty
                  ? Container(
                      color: ColorsFrave.orangeSoft,
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: ColorsFrave.navOrange,
                      ),
                    )
                  : ImageResolver.resolveWidget(
                      category.picture,
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
                  category.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.medium(16, color: ColorsFrave.ink),
                ),
                if (category.description.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    category.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FraveText.light(13, color: ColorsFrave.greyText),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                context.push('/admin/categories/${category.id}');
                return;
              }
              _confirmDelete(context);
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Text(
                  context.l10n.actionEdit,
                  style: FraveText.regular(14, color: ColorsFrave.ink),
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  context.l10n.actionDelete,
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
    final bloc = context.read<CategoryBloc>();
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsFrave.surfaceColor,
        title: Text(
          l10n.adminCategoryDeleteTitle,
          style: FraveText.semiBold(18, color: ColorsFrave.ink),
        ),
        content: Text(
          l10n.adminCategoryDeleteMessage(category.category),
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
    bloc.add(CategoryDeleteRequested(category.id));
  }
}

/// The empty state of the category list.
class _CategoryEmpty extends StatelessWidget {
  const _CategoryEmpty({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.category_outlined,
              size: 56,
              color: ColorsFrave.navOrange,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.adminCategoriesEmpty,
              textAlign: TextAlign.center,
              style: FraveText.regular(15, color: ColorsFrave.greyText),
            ),
            if (hasQuery) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                context.l10n.adminCategorySearchHint,
                textAlign: TextAlign.center,
                style: FraveText.light(13, color: ColorsFrave.lightGrey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
