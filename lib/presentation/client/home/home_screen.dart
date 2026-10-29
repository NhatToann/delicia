import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/products/products_bloc.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../components/app_bottom_nav.dart';
import '../../components/app_nav_destination.dart';
import '../../helpers/category_assets.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import '../cart/cart_screen.dart';
import '../profile/my_profile_screen.dart';
import 'widgets/profile_menu.dart';

/// Signature of the clock that decides the time-of-day greeting.
///
/// The greeting is part of the Figma header, so it cannot simply be
/// removed — but it must not depend on the wall clock either, otherwise
/// golden/geometry tests would render a different string every time they
/// run at another hour of the day. Injecting the clock keeps the app
/// behaviour honest (the real screen uses the real clock) while making the
/// tests reproducible.
typedef HomeClock = DateTime Function();

/// Client home screen (UC-02), built 1:1 from Figma node `47:23`.
///
/// Geometry (frame 393x852):
///
///   header  y0-161   #F5CB58
///     search   x36  y62  200x26  pill radius 30
///     filter   x211 y65  20x20
///     actions  x265 / 298 / 332  y62  26x26  radius 10
///     greeting x34  y104 "Good Morning" 30 bold #F8F8F8
///     subtitle x34  y132 "Rise and shine!..." 13 medium #E95322
///   body    y161-850 #F5F5F5, bottom-left/right radius 30
///     categories y190-269  pill 62x49 radius 30, icon 37
///     divider     y281  x35 w323
///     "Best Seller" y295  20 medium   + "View All" #E95322 12 semiBold
///     promo dots  y585  5 dots 4 tall, active #E95322 rest #F3E9B5
///     banner      y452 w323 h128 r20
///     "Recommend" y610  20 medium
///     "Menu"      y800  20 medium  + 2-line grid
///   footer  y791-851  61 tall
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key, this.clock});

  /// Source of "now" for the time-of-day greeting.
  ///
  /// Defaults to the real clock in the app. Tests pin it to a fixed
  /// instant so the rendered header — and therefore the golden image — is
  /// identical no matter when the suite runs.
  final HomeClock? clock;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

/// Maps a Firebase [Productsdb] to the photo that goes on its home card.
///
/// The mapping lives in [CategoryAssets] and keys off the row's
/// `categoryId` — a stable ASCII slug — rather than its display name, which
/// is Vietnamese and therefore not a dependable key.
String _photoFor(Productsdb p, {int slotIndex = 0}) {
  // Every non-empty picture is forwarded to [ImageResolver], which knows how
  // to load `assets/...`, full http(s) URLs and the legacy relative paths
  // (`products/...`, `categories/...`). Tapping a card opens the same
  // dish the user just saw — no more "burger tile routes to a latte".
  return CategoryAssets.photoFor(p, slotIndex: slotIndex);
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _navIndex = 0;
  int _promoPage = 0;
  bool _showAllBestSellers = false;
  bool _showAllRecommended = false;

  /// Time-of-day greeting shown under the yellow header.
  ///
  /// Reads the hour from the injected clock ([ClientHomeScreen.clock]),
  /// defaulting to the real one, so the header is reproducible in tests.
  String _greeting(BuildContext context) {
    final now = (widget.clock ?? DateTime.now)();
    final hour = now.hour;
    final l10n = context.l10n;
    if (hour < 12) return l10n.greetingMorning;
    if (hour < 18) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  // ---------------- promo carousel ----------------
  final PageController _promoController = PageController(viewportFraction: 1.0);
  Timer? _promoTimer;
  bool _promoUserInteracting = false;

  static const int _promoPageCount = 5;

  void _startPromoAutoPlay() {
    _promoTimer?.cancel();
    _promoTimer = Timer.periodic(const Duration(milliseconds: 3600), (_) {
      if (!mounted || _promoUserInteracting) return;
      if (!_promoController.hasClients) return;
      final next = _promoController.page?.round() ?? 0;
      final target = next >= _promoPageCount - 1 ? 0 : next + 1;
      _promoController.animateToPage(
        target,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
      setState(() => _promoPage = target);
    });
  }

  void _onPromoPageChanged(int page) {
    if (!mounted) return;
    setState(() => _promoPage = page);
  }

  void _onPromoTap(int page) {
    _promoTimer?.cancel();
    if (_promoController.hasClients) {
      _promoController.jumpToPage(page);
    }
    setState(() => _promoPage = page);
    Future<void>.delayed(const Duration(milliseconds: 5000), () {
      if (mounted) _startPromoAutoPlay();
    });
  }

  /// Opens the cart drawer.
  ///
  /// Figma frames 4.3 - A / 4.3 - B draw the cart as a panel that slides in
  /// over the home screen, so the cart button opens the drawer instead of
  /// pushing a route. The empty state is part of the same drawer — there is
  /// no separate "your cart is empty" toast.
  void _openCart() {
    CartOverlay.show(
      context,
      onCheckout: () => context.push('/client/payment'),
    );
  }

  void _onNavTap(int i) {
    if (i == _navIndex && i == AppNavDestination.home) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    setState(() => _navIndex = i);
    // Every screen shares the same routing for the same destination, so
    // the "Orders" tab means the same thing everywhere.
    AppNavDestination.go(context, i);
  }

  /// The header action tiles fire this callback.
  ///
  /// Index 0 is the bell (Figma x298) → the order history, which is where
  /// the customer sees notifications about their dishes. Index 1 is the
  /// basket (Figma x265) → the cart drawer. The person tile (x332) opens
  /// the profile drawer through [HomeHeaderRow.onProfile].
  void _onHeaderAction(int index) {
    switch (index) {
      case 0:
        context.push('/client/orders');
      case 1:
        _openCart();
    }
  }

  /// Tapping the person tile (action_3, Figma x332) opens the slide-out
  /// profile menu. "My Orders" is wired to the real screen; the other rows
  /// are still inert (per the brief: cancel / track land in a later
  /// use-case).
  void _openProfile() {
    final ordersLabel = context.l10n.navOrders;
    final myProfileLabel = context.l10n.profileMyProfile;
    ProfileMenuOverlay.show(
      context,
      onItemTap: (label) {
        if (label == ordersLabel) {
          context.push('/client/orders');
          return;
        }
        if (label == myProfileLabel) {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const MyProfileScreen(),
            ),
          );
          return;
        }
        // Still a placeholder — show which row was tapped so the
        // team can see the wiring while the screen is built.
        debugPrint('ProfileMenu: "$label" is not wired up yet');
      },
    );
  }

  Future<void> _openFilterSheet(List<Category> categories) async {
    if (categories.isEmpty) return;
    final picked = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: ColorsFrave.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ColorsFrave.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.homeFilterByCategory,
                style: FraveText.bold(18),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (_, i) {
                    final c = categories[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: ColorsFrave.pillYellow,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          'assets/figma_home/${CategoryAssets.iconFor(c)}',
                          height: 24,
                        ),
                      ),
                      title: Text(c.category, style: FraveText.medium(14)),
                      onTap: () => Navigator.of(sheetCtx).pop(c),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      context.go('/client/search-category', extra: picked);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProductsBloc>()
        ..add(const OnGetCategoriesEvent())
        ..add(const OnGetHomeFeedEvent())
        ..add(const OnGetAllProductsEvent());
    });
    _startPromoAutoPlay();
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _promoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We use [AnnotatedRegion] to give the OS status bar dark icons on a
    // transparent background so it visually merges with the yellow header.
    // That removes the duplicate "yellow band + system time row" effect.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: ColorsFrave.surfaceColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: ColorsFrave.headerYellow,
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: RefreshIndicator(
              color: ColorsFrave.navOrange,
              onRefresh: () async {
                context.read<ProductsBloc>().add(const OnGetHomeFeedEvent());
                await Future<void>.delayed(const Duration(milliseconds: 500));
              },
              child: BlocConsumer<ProductsBloc, ProductsState>(
                listenWhen: (a, b) => b.error != null && a.error != b.error,
                listener: (context, state) {
                  if (state.error != null) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(context.failure(state.error!)),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                  }
                },
                builder: (context, state) {
                  final categories = state.categories;

                  final bestProducts = state.bestSellers
                      .where((product) => product.isBestSeller)
                      .toList();
                  final recommendedProducts = state.recommendedProducts
                      .where((product) => product.isRecommended)
                      .toList();
                  final bestSlot = _showAllBestSellers
                      ? bestProducts
                      : bestProducts.take(4).toList();
                  final recSlot = _showAllRecommended
                      ? recommendedProducts
                      : recommendedProducts.take(2).toList();

                  return CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: <Widget>[
                      // ---- search pill (Figma y62-87, 200x26 r30) ----
                      // The safe-area top inset above is what carries the OS
                      // status bar; the yellow bleeds into it so we don't
                      // need a redundant status row.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: HomeHeaderRow(
                            onFilter: () => _openFilterSheet(categories),
                            onAction: _onHeaderAction,
                            onProfile: _openProfile,
                          ),
                        ),
                      ),
                      // ---- greeting block (Figma y104-149) ----
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(34, 22, 34, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _greeting(context),
                                style: FraveText.bold(
                                  30,
                                  color: ColorsFrave.onOrange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.homeRiseAndShine,
                                style: FraveText.medium(
                                  13,
                                  color: ColorsFrave.navOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---------------- body (light) ----------------
                      SliverToBoxAdapter(
                        child: _BodyShell(
                          header: HomeCategoryRail(
                            categories: categories,
                            onSelected: (c) =>
                                context.go('/client/search-category', extra: c),
                          ),
                          divider: Container(
                            margin: const EdgeInsets.fromLTRB(35, 11, 35, 0),
                            height: 1,
                            color: ColorsFrave.outlineVariant,
                          ),
                          children: <Widget>[
                            // ---- "Best Seller" header (Figma y295) ----
                            Padding(
                              padding: const EdgeInsets.fromLTRB(35, 12, 35, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      context.l10n.homeBestSeller,
                                      style: FraveText.medium(20),
                                    ),
                                  ),
                                  if (bestProducts.length > 4)
                                    _SectionExpandButton(
                                      expanded: _showAllBestSellers,
                                      onTap: () => setState(() {
                                        _showAllBestSellers =
                                            !_showAllBestSellers;
                                      }),
                                    ),
                                ],
                              ),
                            ),
                            // Figma places four 72x108 cards at x36/119/202/285, y324.
                            Padding(
                              padding: const EdgeInsets.fromLTRB(36, 12, 36, 0),
                              child: _BestGrid(
                                products: bestSlot,
                                onTap: (p) => context.push(
                                  '/client/details-product/${p.id}',
                                ),
                              ),
                            ),

                            // ---- banner carousel (Figma x35 y452 w323 h128) ----
                            const SizedBox(height: 20),
                            PromoCarousel(
                              controller: _promoController,
                              pageCount: _promoPageCount,
                              activePage: _promoPage,
                              onPageChanged: _onPromoPageChanged,
                              onDotTap: _onPromoTap,
                              onInteractStart: () =>
                                  _promoUserInteracting = true,
                              onInteractEnd: () {
                                _promoUserInteracting = false;
                                _startPromoAutoPlay();
                              },
                            ),

                            // ---- "Recommend" header (Figma y610) ----
                            const SizedBox(height: 21),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(35, 0, 35, 0),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      context.l10n.homeRecommend,
                                      style: FraveText.medium(20),
                                    ),
                                  ),
                                  if (recommendedProducts.length > 2)
                                    _SectionExpandButton(
                                      expanded: _showAllRecommended,
                                      onTap: () => setState(() {
                                        _showAllRecommended =
                                            !_showAllRecommended;
                                      }),
                                    ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.fromLTRB(34, 14, 34, 0),
                              child: _MenuGrid(
                                products: recSlot,
                                onTap: (p) => context.push(
                                  '/client/details-product/${p.id}',
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // ---- "Menu" header.  Renders *every* active
                            //      product from Firebase as a 2-column grid
                            //      so the user can see the full catalogue.
                            // ----
                            Padding(
                              padding: const EdgeInsets.fromLTRB(35, 12, 35, 0),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      context.l10n.homeMenu,
                                      style: FraveText.medium(20),
                                    ),
                                  ),
                                  Text(
                                    context.l10n.homeItemCount(
                                      state.allProducts
                                          .where((p) => p.isActive)
                                          .length,
                                    ),
                                    style: FraveText.regular(
                                      12,
                                      color: ColorsFrave.lightGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              child: _MenuGrid(
                                products: state.allProducts
                                    .where((p) => p.isActive)
                                    .toList(),
                                onTap: (p) => context.push(
                                  '/client/details-product/${p.id}',
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            bottomNavigationBar: HomeFooter(
              currentIndex: _navIndex,
              onTap: _onNavTap,
              onTapCart: _openCart,
            ),
          ),
        ),
      ),
    );
  }
}

/// ===================== BEST-SELLER GRID =================================
/// Figma's node 189:3123..189:3126 draws four 71x108 tiles at
/// x 36 / 119 / 202 / 285 with a 12 px gutter and 36 px page inset.
/// The tile aspect ratio is pinned so the layout matches the kit on any
/// phone width.
class _BestGrid extends StatelessWidget {
  const _BestGrid({required this.products, required this.onTap});

  final List<Productsdb> products;
  final ValueChanged<Productsdb> onTap;

  static const int _columns = 4;
  static const double _tileHeight = 108;
  static const double _photoHeight = 72;
  static const double _gap = 11;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          context.l10n.homeNoBestSellers,
          style: FraveText.regular(12, color: ColorsFrave.lightGrey),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisSpacing: _gap,
        crossAxisSpacing: _gap,
        mainAxisExtent: _tileHeight,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        return _ProductTile(
          product: p,
          onTap: () => onTap(p),
          imageAsset: _photoFor(p, slotIndex: i),
        );
      },
    );
  }
}

class _SectionExpandButton extends StatelessWidget {
  const _SectionExpandButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: expanded
          ? context.l10n.homeCollapseSection
          : context.l10n.actionViewAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                expanded
                    ? context.l10n.homeCollapseSection
                    : context.l10n.actionViewAll,
                style: FraveText.semiBold(12, color: ColorsFrave.navOrange),
              ),
              const SizedBox(width: 2),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: ColorsFrave.navOrange,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menu grid — 2 columns of the entire Firebase catalogue.
class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.products, required this.onTap});

  final List<Productsdb> products;
  final ValueChanged<Productsdb> onTap;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            context.l10n.loadingMenu,
            style: FraveText.regular(13, color: ColorsFrave.lightGrey),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        return _MenuCard(product: p, onTap: () => onTap(p));
      },
    );
  }
}

/// Rounded light panel that the Figma draws as `#F5F5F5` with 30 bottom
/// corners, sitting under the yellow header.
class _BodyShell extends StatelessWidget {
  const _BodyShell({
    required this.header,
    required this.divider,
    required this.children,
  });

  final Widget header;
  final Widget divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ColorsFrave.contentBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[header, divider, ...children],
      ),
    );
  }
}

/// ===================== HEADER ROW ======================================
/// Figma: search pill x36 y62 200x26 r30, filter x211 y65 20x20,
/// three action tiles x265/298/332 y62 26x26 r10.
class HomeHeaderRow extends StatelessWidget {
  const HomeHeaderRow({
    super.key,
    this.onFilter,
    this.onAction,
    this.onProfile,
  });

  /// Fired by the filter disc — opens the category sheet.
  final VoidCallback? onFilter;

  /// Fired by the three 26 px action tiles, in Figma left-to-right order:
  /// basket (cart), bell (notifications), person (profile).
  ///
  /// Index 0 is the bell, index 1 is the basket; the person tile is wired
  /// through [onProfile] because the profile drawer is a separate sheet.
  final void Function(int index)? onAction;

  /// Fired by the person tile (Figma x332) — opens the profile drawer.
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Row(
        children: <Widget>[
          Flexible(
            child: SizedBox(
              height: 26,
              child: Material(
                color: ColorsFrave.surfaceColor,
                borderRadius: BorderRadius.circular(30),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/client/search-category'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
                    // Figma pill: magnifier glyph x48..53, label x60… — both
                    // sit in one row so the text can never leave the button.
                    child: Row(
                      children: <Widget>[
                        SvgPicture.asset(
                          'assets/figma_home/search_icon.svg',
                          width: 12,
                          height: 12,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.actionSearch,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: FraveText.family,
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF676767),
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            asset: 'assets/figma_home/filter_icon.svg',
            size: 20,
            tooltip: context.l10n.actionFilter,
            onTap: onFilter,
          ),
          const SizedBox(width: 5),
          // The three 26 px action tiles, in Figma left-to-right order:
          //   x265 = action_1 = basket   → cart drawer
          //   x298 = action_2 = bell     → notifications / orders
          //   x332 = action_3 = person   → profile drawer
          // The glyph inside each asset decides what the button does, so the
          // basket must open the cart and the person must open the profile.
          _HeaderIconButton(
            asset: 'assets/figma_home/action_1.svg',
            size: 26,
            tooltip: context.l10n.navCart,
            onTap: () => onAction?.call(1),
          ),
          const SizedBox(width: 7),
          _HeaderIconButton(
            asset: 'assets/figma_home/action_2.svg',
            size: 26,
            tooltip: context.l10n.homeNotifications,
            onTap: () => onAction?.call(0),
          ),
          const SizedBox(width: 7),
          _HeaderIconButton(
            asset: 'assets/figma_home/action_3.svg',
            size: 26,
            tooltip: context.l10n.profileMyProfile,
            onTap: onProfile,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.asset,
    required this.size,
    required this.tooltip,
    this.onTap,
  });

  final String asset;
  final double size;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
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
}

class HomeCategoryRail extends StatelessWidget {
  const HomeCategoryRail({
    super.key,
    required this.categories,
    required this.onSelected,
  });

  final List<Category> categories;
  final ValueChanged<Category> onSelected;

  /// The fallback chips shown before Firebase answers.
  ///
  /// The labels are internal keys, not display copy: [_defaultLabel] turns
  /// them into the Vietnamese text the customer reads. They never take part
  /// in matching against the Firebase catalogue any more — that is keyed off
  /// the stable `categoryId` in [CategoryAssets].
  static const List<({String label, String icon})> _defaults =
      <({String label, String icon})>[
        (label: 'Snacks', icon: 'cat_snacks.svg'),
        (label: 'Meal', icon: 'cat_meals.svg'),
        (label: 'Vegan', icon: 'cat_vegan.svg'),
        (label: 'Dessert', icon: 'cat_desserts.svg'),
        (label: 'Drinks', icon: 'cat_drinks.svg'),
      ];

  /// The Vietnamese name of a fallback chip.
  static String _defaultLabel(AppLocalizations l10n, String label) {
    switch (label) {
      case 'Snacks':
        return l10n.categorySnacks;
      case 'Meal':
        return l10n.categoryMeal;
      case 'Vegan':
        return l10n.categoryVegan;
      case 'Dessert':
        return l10n.categoryDessert;
      case 'Drinks':
        return l10n.categoryDrinks;
      default:
        return label;
    }
  }

  static const double pillHeight = 62;
  static const double pillWidth = 49;
  static const double _chipPitch = 68;
  static const double _labelGap = 3;

  @override
  Widget build(BuildContext context) {
    final items = categories.isEmpty
        ? _defaults
        : categories
              .take(5)
              .map((c) => (label: c.category, icon: _iconFor(c)))
              .toList();

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(36, 31, 36, 0),
        itemCount: items.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: _chipPitch - pillWidth),
        itemBuilder: (_, i) {
          final item = items[i];
          final category = i < categories.length ? categories[i] : null;
          return GestureDetector(
            onTap: category == null ? null : () => onSelected(category),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: pillWidth,
                  height: pillHeight,
                  decoration: BoxDecoration(
                    color: ColorsFrave.pillYellow,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  // The pill is an *icon* button, never a photo: the row
                  // reads as a set of matching glyphs, and the artwork
                  // comes from `assets/figma_home/cat_*.svg` via
                  // [CategoryAssets.iconFor] (keyed off the stable id).
                  child: SvgPicture.asset(
                    'assets/figma_home/${item.icon}',
                    height: 37,
                  ),
                ),
                const SizedBox(height: _labelGap),
                Text(
                  category == null
                      ? _defaultLabel(context.l10n, item.label)
                      : item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.regular(12, height: 1),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _iconFor(Category c) {
    return CategoryAssets.iconFor(c);
  }
}

/// ===================== PROMO DOTS =====================================
/// Figma y585: five 20x4 rounded bars, active `#E95322`, rest `#F3E9B5`.
class PromoDots extends StatelessWidget {
  const PromoDots({super.key, this.count = 5, this.active = 0, this.onTapDot});

  final int count;
  final int active;
  final ValueChanged<int>? onTapDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (i) {
        final dot = Container(
          width: 20,
          height: 4,
          decoration: BoxDecoration(
            color: i == active ? ColorsFrave.navOrange : ColorsFrave.pillYellow,
            borderRadius: BorderRadius.circular(12),
          ),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapDot == null ? null : () => onTapDot!(i),
            child: Semantics(
              button: onTapDot != null,
              label: context.l10n.homePromoDotLabel(i + 1),
              child: dot,
            ),
          ),
        );
      }),
    );
  }
}

/// Banner + dots wired into one pager.
///
/// Five slides. Each slide uses its own photo so the carousel no longer
/// appears to repeat the same picture with new text.
class PromoCarousel extends StatelessWidget {
  const PromoCarousel({
    super.key,
    required this.controller,
    required this.pageCount,
    required this.activePage,
    required this.onPageChanged,
    required this.onDotTap,
    this.onInteractStart,
    this.onInteractEnd,
  });

  final PageController controller;
  final int pageCount;
  final int activePage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onDotTap;
  final VoidCallback? onInteractStart;
  final VoidCallback? onInteractEnd;

  static const List<String> _photos = <String>[
    'assets/figma_home/img_banner.png',
    'assets/figma_home/card_best_1.png',
    'assets/figma_home/card_best_2.png',
    'assets/figma_home/card_best_3.png',
    'assets/figma_home/card_best_4.png',
  ];

  static List<({String title, String body})> _copy(AppLocalizations l10n) =>
      <({String title, String body})>[
        (title: l10n.homeBadgeDiscount, body: l10n.homeTaglineNewDish),
        (title: l10n.homeBannerBurger, body: l10n.homeBannerBurgerSubtitle),
        (title: l10n.homeBannerPizza, body: l10n.homeBannerPizzaSubtitle),
        (title: l10n.homeBannerFresh, body: l10n.homeBannerFreshSubtitle),
        (title: l10n.homeBannerWeekly, body: l10n.homeBannerWeeklySubtitle),
      ];

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context.l10n);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 128,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) onInteractStart?.call();
              if (n is ScrollEndNotification) onInteractEnd?.call();
              return false;
            },
            child: PageView.builder(
              controller: controller,
              onPageChanged: onPageChanged,
              itemCount: pageCount,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: PromoBanner(
                  imageAsset: _photos[i % _photos.length],
                  headline: copy[i % copy.length].title,
                  caption: copy[i % copy.length].body,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        PromoDots(count: pageCount, active: activePage, onTapDot: onDotTap),
      ],
    );
  }
}

/// ===================== PROMO BANNER ====================================
/// Figma: card x35 y452 323x128 radius 20 on `#E95322`, a photo panel on
/// the right and a copy block on the left.
///
/// Copy and photo widths are calculated from the actual card width, so they
/// remain side by side on narrow devices. Copy is left aligned and the photo
/// stays fully inside the rounded card.
class PromoBanner extends StatelessWidget {
  const PromoBanner({
    super.key,
    required this.imageAsset,
    this.headline,
    this.caption,
  });

  final String imageAsset;

  /// Carousel copy. Kept as parameters so each slide can say something
  /// different while the plate geometry stays identical to Figma.
  ///
  /// Both fall back to the localized default when a slide does not supply
  /// its own copy.
  final String? headline;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final headlineText = headline ?? context.l10n.homeBadgeDiscount;
    final captionText = caption ?? context.l10n.homeTaglineNewDish;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final photoWidth = (cardWidth * .38).clamp(76.0, 118.0);
        final copyWidth = (cardWidth - photoWidth - 38).clamp(70.0, cardWidth);
        return SizedBox(
          height: 128,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                Positioned.fill(
                  child: ColoredBox(color: ColorsFrave.navOrange),
                ),
                // Yellow accent rings (Figma ellipses). They sit *behind* the
                // photo and peek out past its top-right / bottom-right corners.
                // Both are fully inside the card, so nothing bleeds over the
                // rounded edge.
                Positioned(
                  right: 2,
                  top: 2,
                  child: SvgPicture.asset(
                    'assets/figma_home/banner_dot1.svg',
                    width: 48,
                    height: 48,
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 2,
                  child: SvgPicture.asset(
                    'assets/figma_home/banner_dot2.svg',
                    width: 40,
                    height: 40,
                  ),
                ),
                // Photo panel — inset on every side and rounded, so the image
                // never bleeds past the card edge.
                Positioned(
                  right: 12,
                  top: 12,
                  bottom: 12,
                  width: photoWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: ColorsFrave.navOrange),
                    ),
                  ),
                ),
                // Copy block — 16 px gutter, vertically centred, and scaled
                // down when the headline needs more room than the card has.
                Positioned(
                  left: 14,
                  top: 0,
                  bottom: 0,
                  width: copyWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            captionText,
                            textAlign: TextAlign.left,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FraveText.regular(
                              10,
                              color: ColorsFrave.onOrange,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            headlineText,
                            textAlign: TextAlign.left,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FraveText.bold(
                              17,
                              color: ColorsFrave.onOrange,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ===================== PRODUCT TILE (BEST-SELLER) ======================
/// 71 x 108 cell. Photo on top (Figma x36 y324), rating chip + heart chip
/// floating, price chip on the top-left, name + price caption underneath.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.imageAsset,
  });

  final Productsdb product;
  final VoidCallback onTap;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              height: _BestGrid._photoHeight,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ImageResolver.resolveWidget(
                        imageAsset,
                        fit: BoxFit.cover,
                        fallback: CategoryAssets.pool.first,
                      ),
                    ),
                  ),
                  // Rating chip — the ONLY badge on the photo.
                  //
                  // The tile is just 71 px wide, so every overlay badge
                  // competes with the food photo and with the other tiles.
                  // The price already sits right below the photo (bigger and
                  // bolder), and the favourite toggle has its own nav tab, so
                  // both overlay chips were pure noise. What survives is the
                  // star score — the one number that tells the customer
                  // whether the dish is worth the price.
                  Positioned(
                    left: 4,
                    bottom: 6,
                    child: Container(
                      height: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: ColorsFrave.surfaceColor,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: FraveText.regular(9, height: 1),
                          ),
                          const SizedBox(width: 2),
                          SvgPicture.asset(
                            'assets/figma_home/star.svg',
                            width: 8,
                            height: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              product.nameProduct,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FraveText.medium(11, height: 1),
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (product.oldPrice != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 3, bottom: 2),
                    child: Text(
                      Money.format(product.oldPrice!),
                      maxLines: 1,
                      style:
                          FraveText.regular(
                            9,
                            color: ColorsFrave.outlineVariant,
                            height: 1,
                          ).copyWith(
                            decoration: TextDecoration.lineThrough,
                            decorationColor: ColorsFrave.outlineVariant,
                          ),
                    ),
                  ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Money.format(product.price),
                      maxLines: 1,
                      style: FraveText.bold(
                        14,
                        color: ColorsFrave.navOrange,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ===================== FAVOURITE ICON ===================================
/// Reads the current favourite state from [ProductsBloc], dispatches the
/// toggle event on tap, and renders the right SVG accordingly. No more
/// hardcoded `favorite_on.svg` everywhere.
class _FavoriteIcon extends StatelessWidget {
  const _FavoriteIcon({required this.product});

  final Productsdb product;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductsBloc, ProductsState>(
      buildWhen: (a, b) =>
          a.favorites.contains(product.id) != b.favorites.contains(product.id),
      builder: (context, state) {
        final isFav = state.favorites.contains(product.id);
        return SizedBox(
          width: 22,
          height: 22,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              context.read<ProductsBloc>().add(
                OnToggleFavoriteEvent(product.id),
              );
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      isFav
                          ? context.l10n.homeRemoveProductFromFavourites(
                              product.nameProduct,
                            )
                          : context.l10n.homeProductSaved(product.nameProduct),
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 900),
                  ),
                );
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: SvgPicture.asset(
                isFav
                    ? 'assets/figma_home/favorite_on.svg'
                    : 'assets/figma_home/favorite_off.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ===================== MENU CARD =======================================
/// Two-column entry in the full-catalogue grid. Same layout language as
/// the existing `ProductCard`, but tied to the real price / rating /
/// favourite state from [ProductsBloc].
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.product, required this.onTap});

  final Productsdb product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: ColorsFrave.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: ColorsFrave.surfaceVariant,
                      child: ImageResolver.resolveWidget(
                        product.picture.trim().isNotEmpty
                            ? product.picture
                            : _photoFor(product),
                        fit: BoxFit.cover,
                        fallback: CategoryAssets.pool.first,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: ColorsFrave.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SvgPicture.asset(
                            'assets/figma_home/star.svg',
                            width: 9,
                            height: 9,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: FraveText.regular(10, height: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _FavoriteIcon(product: product),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      product.nameProduct,
                      style: FraveText.semiBold(
                        13,
                        color: ColorsFrave.darkText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            Money.format(product.price),
                            style: FraveText.bold(
                              15,
                              color: ColorsFrave.navOrange,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: ColorsFrave.navOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: ColorsFrave.onOrange,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===================== FOOTER ==========================================
/// The app-wide bottom bar.
///
/// This is a thin alias kept so the home screen (and the tests that
/// reference `HomeFooter`) keep working while the bar itself lives in
/// [AppBottomNav] — the single implementation every screen shares.
class HomeFooter extends StatelessWidget {
  const HomeFooter({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onTapCart,
    this.cartCount,
  });

  final int currentIndex;

  /// Optional override. When null the badge is read live from `CartBloc`.
  final int? cartCount;
  final ValueChanged<int> onTap;
  final VoidCallback onTapCart;

  @override
  Widget build(BuildContext context) {
    return AppBottomNav(
      currentIndex: currentIndex,
      cartCount: cartCount,
      // When no override is given the bar reads the count from the cart bloc —
      // that way the badge stays live on every screen.
      onTap: onTap,
      onTapCart: onTapCart,
    );
  }
}
