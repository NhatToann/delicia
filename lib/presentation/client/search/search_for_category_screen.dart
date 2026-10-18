import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/products/products_bloc.dart';
import '../../../domain/models/category.dart';
import '../../components/form_field_frave.dart';
import '../../components/shimmer_frave.dart';
import '../../components/text_custom.dart';
import '../../themes/colors_frave.dart';
import '../home/widgets/product_card.dart';

/// SearchForCategoryScreen — full-screen search + category filter grid.
///
/// Wired into:
/// - `OnSearchProductEvent(query)` to debounce the typed query
/// - `OnSelectCategoryEvent(id, name)` to override the current category
class SearchForCategoryScreen extends StatefulWidget {
  final Category? category;
  const SearchForCategoryScreen({super.key, this.category});

  @override
  State<SearchForCategoryScreen> createState() =>
      _SearchForCategoryScreenState();
}

class _SearchForCategoryScreenState extends State<SearchForCategoryScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<ProductsBloc>();
      if (widget.category != null) {
        bloc.add(OnSelectCategoryEvent(
          idCategory: widget.category!.id,
          category: widget.category!.category,
        ));
      } else {
        bloc.add(const OnClearSearchEvent());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          onPressed: () => context.pop(),
        ),
        title: TextCustom(
          widget.category?.category ?? 'Search',
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            FormFieldFrave(
              controller: _controller,
              hintText: 'Search product...',
              prefixIcon: Icons.search,
              onChanged: (v) {
                context
                    .read<ProductsBloc>()
                    .add(OnSearchProductEvent(v));
              },
            ),
            const SizedBox(height: 16),
            BlocBuilder<ProductsBloc, ProductsState>(
              builder: (_, state) {
                if (state.selectedCategoryName != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_outlined,
                          size: 16,
                          color: ColorsFrave.greyText,
                        ),
                        const SizedBox(width: 4),
                        TextCustom(
                          'Category: ${state.selectedCategoryName}',
                          fontSize: 13,
                          color: ColorsFrave.greyText,
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            _controller.clear();
                            context
                                .read<ProductsBloc>()
                                .add(const OnClearSearchEvent());
                          },
                          child: const TextCustom(
                            'Clear',
                            color: ColorsFrave.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: BlocBuilder<ProductsBloc, ProductsState>(
                builder: (_, state) {
                  if (state.isLoadingSearch) {
                    return const ShimmerProductsGrid();
                  }
                  if (state.searchResults.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: ColorsFrave.greyText,
                          ),
                          SizedBox(height: 8),
                          TextCustom(
                            'No results',
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: state.searchResults.length,
                    itemBuilder: (_, i) {
                      final p = state.searchResults[i];
                      return ProductCard(
                        product: p,
                        onTap: () => context.push(
                          '/client/details-product/${p.id}',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}