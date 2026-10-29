import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';

/// Pure presentation widget for the Launch Welcome screen.
///
/// Design reference: `assets/.../0 - B - Launch Welcome Screen.png`
/// (393x852, orange #E95322 background, yellow #F5CB58 illustration and
/// headline, yellow + cream pills at the bottom).
class LaunchWelcomeView extends StatelessWidget {
  const LaunchWelcomeView({super.key, required this.animation});

  final Animation<double> animation;

  /// Staggered entrance for the artwork, headline, copy and buttons.
  Animation<double> _fade(int beginMs, int endMs) => CurvedAnimation(
    parent: animation,
    curve: Interval(beginMs / 1000, endMs / 1000, curve: Curves.easeOut),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsFrave.welcomeBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The artwork shrinks on short devices so the two pills at the
            // bottom are never pushed off-screen. This was the source of the
            // "RenderFlex overflowed by N pixels" report.
            final artHeight = (constraints.maxHeight * 0.24).clamp(110.0, 180.0);

            // Enough room for art + headline + copy + two pills? If not, the
            // column scrolls instead of overflowing.
            final contentHeight = artHeight + 190 + 56 + 14 + 56 + 40;
            final fits = constraints.maxHeight >= contentHeight;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      if (fits) const Spacer(flex: 2),

                      FadeTransition(
                        opacity: _fade(0, 400),
                        child: SizedBox(
                          height: artHeight,
                          child: SvgPicture.asset(
                            'assets/logos/delicia-courier.svg',
                            fit: BoxFit.contain,
                            colorFilter: const ColorFilter.mode(
                              ColorsFrave.welcomeAccent,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),

                      if (fits) const Spacer(flex: 1) else const SizedBox(height: 28),

                      FadeTransition(
                        opacity: _fade(120, 520),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            context.l10n.introWelcome,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 34,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: ColorsFrave.welcomeAccent,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      FadeTransition(
                        opacity: _fade(220, 560),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 44),
                          child: Text(
                            context.l10n.introDescription,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: ColorsFrave.welcomeOnBg,
                            ),
                          ),
                        ),
                      ),

                      if (fits) const Spacer(flex: 2) else const SizedBox(height: 32),

                      FadeTransition(
                        opacity: _fade(320, 560),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: WelcomePill(
                            label: context.l10n.actionSignIn,
                            background: ColorsFrave.welcomeAccent,
                            foreground: ColorsFrave.welcomeBg,
                            onTap: () => context.push('/login'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      FadeTransition(
                        opacity: _fade(400, 560),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: WelcomePill(
                            label: context.l10n.introCreateAccount,
                            background: ColorsFrave.welcomeSecondary,
                            foreground: ColorsFrave.welcomeBg,
                            onTap: () => context.push('/register'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pill-shaped button used by the Welcome screen.
///
/// The label is single-line with an ellipsis and the button has an explicit
/// height, so a long label can never overflow horizontally or vertically.
class WelcomePill extends StatelessWidget {
  const WelcomePill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 56),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(RadiusFrave.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 56,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
