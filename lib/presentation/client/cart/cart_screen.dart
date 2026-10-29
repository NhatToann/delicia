import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/bloc/cart/cart_bloc.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';
import 'widgets/cart_panel.dart';

/// Cart host.
///
/// The Figma frames 4.3 - A and 4.3 - B draw the cart as a **drawer over the
/// home screen** — an orange panel that slides in from the right edge while
/// the home screen stays visible behind a `#FE4A0C @ 31 %` scrim. That is the
/// same pattern the project already uses for the profile drawer
/// (`ProfileMenuOverlay`), so the cart reuses it instead of inventing a
/// second drawer vocabulary.
///
/// The panel itself lives in [CartPanel]; this class only hosts it.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: ColorsFrave.navOrange,
      body: CartPanel(),
    );
  }
}

/// Full-screen host for the cart drawer.
///
/// Slides the panel in from the right edge, dims the rest with the Figma's
/// orange scrim, and closes on any tap outside the panel.
class CartOverlay {
  /// The Figma scrim: `#FE4A0C` at 31 % over the home screen.
  static const Color backdropColour = Color(0x4DFE4A0C);

  /// Presents the drawer. Call from the cart button's `onTap`.
  static void show(BuildContext context, {void Function()? onCheckout}) {
    final bloc = context.read<CartBloc>();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.cartClose,
      barrierColor: CartOverlay.backdropColour,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => BlocProvider<CartBloc>.value(
        value: bloc,
        child: CartDrawerOverlay(onCheckout: onCheckout),
      ),
      transitionBuilder: (_, animation, _, child) {
        // Slide from the right, fading the panel itself in.
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }
}

/// The stateful drawer UI is kept in its own widget type so the stable
/// [CartOverlay.show] entry point does not change when its implementation does.
class CartDrawerOverlay extends StatefulWidget {
  const CartDrawerOverlay({super.key, this.onCheckout});

  /// Fired when the user taps Checkout inside the panel.
  final VoidCallback? onCheckout;

  @override
  State<CartDrawerOverlay> createState() => _CartOverlayState();
}

class _CartOverlayState extends State<CartDrawerOverlay> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Figma: 330 px panel on a 393 px frame. Scale the ratio so a 360 px
    // phone still shows the same ~16 % strip of backdrop on the left.
    final panelWidth = (width * 0.84).clamp(240.0, width);

    return Stack(
      children: <Widget>[
        // Tap-outside catcher. `showGeneralDialog`'s own barrier already
        // dismisses on an outside tap, but this explicit layer keeps the
        // behaviour obvious and testable.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: GestureDetector(
              // Swallow taps so they do not reach the dismiss layer.
              onTap: () {},
              child: CartPanel(onCheckout: _handleCheckout),
            ),
          ),
        ),
      ],
    );
  }

  void _handleCheckout() {
    // Close the drawer first so the host's navigation isn't stacked on top
    // of the dialog route. The host callback runs on the next frame for the
    // same reason — by then the dialog is gone from the navigator.
    Navigator.of(context).maybePop();
    final host = widget.onCheckout;
    if (host == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => host());
  }
}
