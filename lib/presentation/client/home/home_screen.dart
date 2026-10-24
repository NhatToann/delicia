import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/cart/cart_bloc.dart';
import '../../../domain/bloc/products/products_bloc.dart';
import '../../../domain/models/address.dart';
import '../../../domain/models/category.dart';
import '../../components/shimmer_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/date_custom.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../themes/colors_frave.dart';
import 'widgets/category_filter.dart';
import 'widgets/product_card.dart';

/// ClientHomeScreen — main landing screen for the customer role (UC-02).
///
/// Shows:
///  - Greeting with the avatar (from AuthBloc)
///  - Cart icon with the badge count (from CartBloc)
///  - Search bar (tap → SearchForCategoryScreen)
///  - Horizontal category filter
///  - Grid of top products
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  /// The user-selected delivery address. `null` means "no address
  /// chosen yet" — the address card shows a "Choose delivery
  /// address" placeholder.
  Address? _selectedAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<ProductsBloc>();
      bloc.add(const OnGetCategoriesEvent());
      bloc.add(const OnGetTopProductsEvent());
    });
  }

  Future<void> _pickAddress() async {
    debugPrint('[delicia] _pickAddress → push /client/select-address');
    final result = await context.push<Address>(
      '/client/select-address',
    );
    debugPrint('[delicia] _pickAddress → returned $result');
    if (result != null && mounted) {
      setState(() => _selectedAddress = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final cartCount = context.watch<CartBloc>().state.quantityCart;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: ColorsFrave.primaryColor,
          onRefresh: () async {
            final bloc = context.read<ProductsBloc>();
            bloc.add(const OnGetCategoriesEvent());
            bloc.add(const OnGetTopProductsEvent());
            await Future<void>.delayed(const Duration(milliseconds: 600));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 12),
              _Header(
                avatarUrl: auth.user?.image,
                firstName: auth.user?.firstName ?? '',
                cartCount: cartCount,
                onCartPressed: () => context.push('/client/cart'),
              ),
              const SizedBox(height: 16),
              _SearchBar(
                onTap: () => context.push('/client/search-category'),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(right: 50.0),
                child: TextCustom(
                  'What do you want to eat today?',
                  fontSize: 24,
                  maxLines: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              _AddressCard(
                address: _selectedAddress,
                onTap: _pickAddress,
              ),
              const SizedBox(height: 20),
              const TextCustom(
                'Categories',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 12),
              BlocConsumer<ProductsBloc, ProductsState>(
                listenWhen: (a, b) => b.error != null && a.error != b.error,
                listener: (_, state) {
                  if (state.error != null) {
                    errorMessageSnack(context, state.error!);
                  }
                },
                builder: (_, state) {
                  if (state.isLoadingCategories && state.categories.isEmpty) {
                    return const ShimmerCategories();
                  }
                  return CategoryFilter(
                    categories: state.categories,
                    selectedCategoryId: state.selectedCategoryId,
                    onSelected: (c) => _onCategorySelected(c),
                  );
                },
              ),
              const SizedBox(height: 20),
              const TextCustom(
                'Popular Items',
                fontSize: 21,
                fontWeight: FontWeight.w500,
              ),
              const SizedBox(height: 12),
              BlocBuilder<ProductsBloc, ProductsState>(
                builder: (_, state) {
                  if (state.isLoadingTopProducts && state.topProducts.isEmpty) {
                    return const ShimmerProductsGrid();
                  }
                  if (state.topProducts.isEmpty) {
                    return _EmptyState(
                      title: 'No products yet',
                      subtitle: 'Check back later for new items.',
                    );
                  }
                  return _ProductsGrid(products: state.topProducts);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _onCategorySelected(Category c) {
    final bloc = context.read<ProductsBloc>();
    bloc.add(OnSelectCategoryEvent(
      idCategory: c.id,
      category: c.category,
    ));
    context.push('/client/search-category', extra: c);
  }
}

class _ProductsGrid extends StatelessWidget {
  final List products;
  const _ProductsGrid({required this.products});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        return ProductCard(
          product: p,
          onTap: () => context.push(
            '/client/details-product/${p.id}',
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String? avatarUrl;
  final String firstName;
  final int cartCount;
  final VoidCallback onCartPressed;

  const _Header({
    required this.avatarUrl,
    required this.firstName,
    required this.cartCount,
    required this.onCartPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: ColorsFrave.backgroundColor,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: (avatarUrl == null || avatarUrl!.isEmpty)
              ? const Icon(
                  Icons.person,
                  color: ColorsFrave.primaryColor,
                )
              : ImageResolver.resolveWidget(
                  avatarUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextCustom(
            '${DateCustom.getDateFrave()}, ${firstName.isEmpty ? 'there' : firstName}',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(
                Icons.shopping_bag_outlined,
                size: 28,
                color: ColorsFrave.darkText,
              ),
              onPressed: onCartPressed,
            ),
            if (cartCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: ColorsFrave.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: TextCustom(
                    cartCount.toString(),
                    fontSize: 11,
                    color: Colors.white,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ColorsFrave.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: const [
            Icon(Icons.search, color: ColorsFrave.greyText),
            SizedBox(width: 10),
            TextCustom(
              'Search products or restaurants',
              color: ColorsFrave.greyText,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Address? address;
  final VoidCallback onTap;
  const _AddressCard({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasAddress = address != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: ColorsFrave.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasAddress
                  ? Icons.location_on
                  : Icons.location_on_outlined,
              size: 26,
              color: ColorsFrave.primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextCustom(
                  'Deliver to',
                  fontSize: 12,
                  color: ColorsFrave.greyText,
                ),
                const SizedBox(height: 2),
                TextCustom(
                  hasAddress ? address!.street : 'Choose delivery address',
                  color: ColorsFrave.primaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: ColorsFrave.greyText,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 64,
            color: ColorsFrave.greyText,
          ),
          const SizedBox(height: 8),
          TextCustom(title, fontSize: 18, fontWeight: FontWeight.w600),
          const SizedBox(height: 4),
          TextCustom(
            subtitle,
            color: ColorsFrave.greyText,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
