import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';

/// Pure presentation widget for the Launch First screen.
///
/// Kept free of BLoC/router dependencies so it can be reused in previews
/// and widget tests without booting Firebase.
///
/// Layout: the brand block (courier mark + wordmark + tagline) is centred in
/// the viewport and the round CTA is pinned to the bottom.
///
/// The layout is built from a full-bleed [Stack] of [Align]s rather than a
/// [SafeArea] + [Column] of [Spacer]s.
///
/// Two things pushed the brand block off-centre before:
///   * [SafeArea] only guarantees a *minimum* inset. On a device that reports
///     asymmetric insets (notch / cutout / gesture bar) it widens the safe box
///     on one side only, so "centred" inside the safe box is no longer
///     centred on the physical screen.
///   * A [Column] distributes leftover space along the *main* axis only, so
///     children were positioned relative to that same off-centre box.
///
/// A splash is a brand card, not a form: there is nothing to protect from an
/// overlap, so it is laid out edge-to-edge and every element is centred by
/// [Align] against the true viewport. The CTA is the only thing near a system
/// gesture, so it alone takes the bottom inset — via `max`, which never makes
/// it sit higher than the designed 40 px.
class LaunchFirstView extends StatelessWidget {
  const LaunchFirstView({
    super.key,
    required this.animation,
    required this.onContinue,
  });

  final Animation<double> animation;
  final VoidCallback onContinue;

  /// Curved, clamped window used for the staggered entrance.
  Animation<double> _fade(int beginMs, int endMs) => CurvedAnimation(
    parent: animation,
    curve: Interval(beginMs / 1000, endMs / 1000, curve: Curves.easeOut),
  );

  @override
  Widget build(BuildContext context) {
    // Keep the CTA clear of the gesture bar, but never above the designed
    // 40 px — `max` instead of `+`, so a zero inset keeps the Figma position.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final ctaBottom = math.max(40.0, bottomInset + 16);

    return Scaffold(
      backgroundColor: ColorsFrave.launchBg,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
            // ---- Brand block, optically centred on the screen --------------
            Align(
              alignment: const Alignment(0, -0.14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Brand mark -- the orange courier illustration from Figma
                  // node 204:3743 ("Capa_2"). Its viewBox is 208.189x185.136
                  // and the frame sizes it at 202x179, so the box keeps that
                  // 1.128 ratio rather than forcing a square.
                  FadeTransition(
                    opacity: _fade(0, 750),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.86, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: const Interval(0, 0.8, curve: Curves.easeOutBack),
                        ),
                      ),
                      child: SizedBox(
                        width: 202,
                        height: 179,
                        child: SvgPicture.asset(
                          'assets/logos/delicia-courier.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // `width: double.infinity` + `textAlign: center` makes the
                  // *ink* centre on the screen, not just the text box.
                  FadeTransition(
                    opacity: _fade(200, 1000),
                    child: const SizedBox(
                      width: double.infinity,
                      child: Text(
                        'DELICIA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: ColorsFrave.launchAccent,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  FadeTransition(
                    opacity: _fade(350, 1000),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        context.l10n.introTagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: ColorsFrave.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- Round CTA, pinned to the bottom ---------------------------
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: ctaBottom),
                child: FadeTransition(
                  opacity: _fade(500, 1000),
                  child: LaunchRoundCta(onTap: onContinue),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

/// The orange circular arrow button at the bottom of the Launch First screen.
class LaunchRoundCta extends StatelessWidget {
  const LaunchRoundCta({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.actionContinue,
      child: Material(
        color: ColorsFrave.launchAccent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: ColorsFrave.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}