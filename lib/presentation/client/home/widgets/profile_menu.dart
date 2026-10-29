import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../domain/bloc/auth/auth_bloc.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../helpers/image_resolver.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// ProfileMenu — the slide-out drawer from Figma node `205:1627`
/// ("4.1 - A - Profile").
///
/// Geometry from the Figma frame (393 x 852):
///
///   backdrop  #FE4A0C @ 31% over the left 174 px
///   panel     x63 w330, fill #E95322, left corners r80 (menu_bg.svg)
///   avatar    x33  y71   50 x 50  (circle)
///   name      x169 y73   League Spartan Medium 33 #F8F8F8
///   email     x169 y104  League Spartan Medium 16 #F3E9B5
///   rows      x33  w?    15 px rounded tile, icon left, label x169
///             My Orders  y181 · My Profile y255 · Delivery Address y329
///             Payment Methods y403 · Contact Us y478 · Help & FAQs y552
///             Settings y626
///   log out   x50  y724  32 px tile + "Log Out" x169 y730 (24 px #F3E9B5)
///
/// Rows are decorative for now — tapping one only reports which row it was,
/// per the brief ("các button thì chưa cần phải làm").
class ProfileMenu extends StatelessWidget {
  const ProfileMenu({super.key, this.onItemTap});

  /// Fired when a menu row is tapped. Receives the row's localized label so
  /// the host can decide what (if anything) to do once real navigation lands.
  final void Function(String label)? onItemTap;

  /// Rows as declared in the Figma node, in top-to-bottom order.
  static List<ProfileMenuItem> items(AppLocalizations l10n) => <ProfileMenuItem>[
    ProfileMenuItem(label: l10n.navOrders, icon: 'assets/figma_home/menu_i1_orders.svg'),
    ProfileMenuItem(label: l10n.profileMyProfile, icon: 'assets/figma_home/menu_i2_profile.svg'),
    ProfileMenuItem(label: l10n.profileDeliveryAddress, icon: 'assets/figma_home/menu_i3_address.svg'),
    ProfileMenuItem(label: l10n.profilePaymentMethods, icon: 'assets/figma_home/menu_i4_payment.svg'),
    ProfileMenuItem(label: l10n.profileContactUs, icon: 'assets/figma_home/menu_i5_contact.svg'),
    ProfileMenuItem(label: l10n.profileHelpFaqs, icon: 'assets/figma_home/menu_i6_help.svg'),
    ProfileMenuItem(label: l10n.profileSettings, icon: 'assets/figma_home/menu_i7_settings.svg'),
  ];

  /// `Log Out` sits in its own group near the bottom of the panel.
  static ProfileMenuItem logoutItem(AppLocalizations l10n) => ProfileMenuItem(
    label: l10n.profileSignOut,
    icon: 'assets/figma_home/menu_i8_logout.svg',
  );

  static const Color panelColour = ColorsFrave.navOrange;
  static const Color labelColour = Color(0xFFF3E9B5); // Yellow 2
  static const Color nameColour = Color(0xFFF8F8F8); // Font 2
  static const Color tileColour = Color(0xFFF8F8F8);
  static const Color backdropColour = Color(0x4DFE4A0C); // #FE4A0C @ 31%

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state.user;
        final l10n = context.l10n;
        final menuItems = ProfileMenu.items(l10n);
        final logout = ProfileMenu.logoutItem(l10n);
        return Material(
          color: panelColour,
          // Only the two left corners are rounded; the panel is flush to the
          // right edge of the screen, exactly like menu_bg.svg.
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(80),
            bottomLeft: Radius.circular(80),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            bottom: false,
            right: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The Figma panel is 330 px wide on a 393 px frame, so it
                // leaves a 63 px strip of backdrop visible on the left.
                final width = constraints.maxWidth;
                final horizontalInset = (width * 0.16).clamp(24.0, 72.0);
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalInset,
                    24,
                    20,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _MenuHeader(user: user),
                        const SizedBox(height: 28),
                        // Rows are pinned to the panel's left edge, matching
                        // the Figma x33 tile / x169 label alignment.
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              for (final item in menuItems)
                                _MenuRow(
                                  item: item,
                                  onTap: () => onItemTap?.call(item.label),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        Padding(
                          padding: EdgeInsets.only(left: horizontalInset * 0.55),
                          child: _MenuRow(
                            item: logout,
                            onTap: () => onItemTap?.call(logout.label),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Avatar + name + email block (Figma y71–140).
class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    final name = _readUserField(user, 'fullName');
    final email = _readUserField(user, 'email');
    final image = _readUserField(user, 'image');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // 50 x 50 avatar. The Figma ships a bitmap; we fall back to it and
        // then to an initials circle so a logged-out user still renders.
        ClipOval(
          child: SizedBox(
            width: 50,
            height: 50,
            child: image == null || image.toString().trim().isEmpty
                ? Image.asset(
                    'assets/figma_home/profile_avatar.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _InitialsAvatar(),
                  )
                : ImageResolver.resolveWidget(
                    image.toString(),
                    fit: BoxFit.cover,
                    fallback: 'assets/figma_home/profile_avatar.png',
                  ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                name == null || name.isEmpty ? context.l10n.profileGuest : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FraveText.medium(
                  26,
                  color: ProfileMenu.nameColour,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email == null || email.isEmpty
                    ? context.l10n.profileNotSignedIn
                    : email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FraveText.medium(
                  14,
                  color: ProfileMenu.labelColour,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Reads a field off the [User] model without importing the type, so the
/// widget stays usable from a test that hands in a stub.
String? _readUserField(dynamic user, String field) {
  if (user == null) return null;
  dynamic Function() pick;
  switch (field) {
    case 'fullName':
      pick = () => user.fullName;
      break;
    case 'email':
      pick = () => user.email;
      break;
    case 'image':
      pick = () => user.image;
      break;
    default:
      return null;
  }
  try {
    return pick()?.toString();
  } catch (_) {
    return null;
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ProfileMenu.labelColour,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 26,
        color: ProfileMenu.panelColour,
      ),
    );
  }
}

/// One row: a 15 px rounded white tile holding the icon, plus the label to
/// its right. The whole row is the tap target.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, this.onTap});

  final ProfileMenuItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ProfileMenu.tileColour,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SvgPicture.asset(
                  item.icon,
                  width: 18,
                  height: 18,
                  // Figma draws every glyph in the brand orange.
                  colorFilter: const ColorFilter.mode(
                    ProfileMenu.panelColour,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.medium(
                    20,
                    color: ProfileMenu.labelColour,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single drawer row. Kept as its own class so the list can be built from
/// data (and asserted in tests) rather than hard-coded positionally.
class ProfileMenuItem {
  const ProfileMenuItem({required this.label, required this.icon});
  final String label;
  final String icon;
}

/// Full-screen host for [ProfileMenu].
///
/// Slides the panel in from the right edge, dims the rest with the Figma's
/// orange scrim, and closes on any tap outside the panel.
class ProfileMenuOverlay extends StatefulWidget {
  const ProfileMenuOverlay({super.key, this.onItemTap});

  final void Function(String label)? onItemTap;

  /// Presents the overlay. Call from the profile button's `onTap`.
  static void show(
    BuildContext context, {
    void Function(String label)? onItemTap,
  }) {
    final bloc = context.read<AuthBloc>();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.profileCloseMenu,
      barrierColor: ProfileMenu.backdropColour,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => BlocProvider<AuthBloc>.value(
        value: bloc,
        child: ProfileMenuOverlay(onItemTap: onItemTap),
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

  @override
  State<ProfileMenuOverlay> createState() => _ProfileMenuOverlayState();
}

class _ProfileMenuOverlayState extends State<ProfileMenuOverlay> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Figma: 330 px panel on a 393 px frame. Scale the ratio so a 360 px
    // phone still shows the same ~10% of backdrop.
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
              child: ProfileMenu(onItemTap: _handleItemTap),
            ),
          ),
        ),
      ],
    );
  }

  void _handleItemTap(String label) {
    // Close the drawer first so the host's navigation isn't stacked on
    // top of the dialog route. The host callback runs on the next frame
    // for the same reason — by then the dialog is gone from the
    // navigator and a `context.push` lands on the page underneath.
    Navigator.of(context).maybePop();
    final host = widget.onItemTap;
    if (host == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      host(label);
    });
  }
}
