import 'package:flutter/material.dart';

import '../themes/colors_frave.dart';

/// Header band used by every auth screen — matches the UI kit's
/// Login / Forgot / Sign Up banner: yellow band, dark back chevron on the
/// left, dark title centred, optional subtitle.
///
/// Sizes follow the 393x852 design ratio; the icons sit at 20sp per the
/// "make icons a little smaller" request.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ColorsFrave.authAccentYellow,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAlias,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onBack,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: ColorsFrave.authInk,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ColorsFrave.authInk,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cream-coloured pill button matching the 2-A "Sign In" primary CTA.
/// Optional leading icon (kept small to match the "smaller icons" brief).
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: ColorsFrave.welcomeSecondary,
        borderRadius: BorderRadius.circular(RadiusFrave.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ColorsFrave.authInk,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16, color: ColorsFrave.authInk),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ColorsFrave.authInk,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Outlined pill button used for "Sign Up" / "Send" secondary actions.
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(RadiusFrave.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RadiusFrave.button),
              border: Border.all(
                color: ColorsFrave.authAccent,
                width: 1.4,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: ColorsFrave.authAccent),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ColorsFrave.authAccent,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tinted divider with a label centred between two lines (e.g.
/// "Or continue with").
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: ColorsFrave.outlineVariant,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ColorsFrave.authInkSoft,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: ColorsFrave.outlineVariant,
          ),
        ),
      ],
    );
  }
}

/// Row of 3 circular social icons used below "Or continue with".
/// Brand colours match the UI kit (Facebook · Google · Apple).
class AuthSocialRow extends StatelessWidget {
  const AuthSocialRow({super.key, required this.onFacebook, required this.onGoogle, required this.onApple});

  final VoidCallback onFacebook;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(
          icon: _fbIcon(),
          background: const Color(0xFF1D78F2),
          onTap: onFacebook,
        ),
        const SizedBox(width: 18),
        _SocialButton(
          icon: _googleIcon(),
          background: const Color(0xFFFFFFFF),
          borderColor: ColorsFrave.outlineVariant,
          onTap: onGoogle,
        ),
        const SizedBox(width: 18),
        _SocialButton(
          icon: _appleIcon(),
          background: const Color(0xFF1D2127),
          foreground: const Color(0xFFFFFFFF),
          onTap: onApple,
        ),
      ],
    );
  }

  // glyphs drawn with Text on colored chips because we don't ship SVG
  // social logos; the smaller icon size keeps them readable.
  static Widget _fbIcon() => const Text(
        'f',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFFFFFF),
          height: 1.05,
        ),
      );
  static Widget _googleIcon() => const Text(
        'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4A6FA5),
          height: 1.05,
        ),
      );
  static Widget _appleIcon() => const Icon(
        Icons.apple_rounded,
        size: 22,
        color: Color(0xFFFFFFFF),
      );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.background,
    required this.onTap,
    this.borderColor,
    this.foreground,
  });

  final Widget icon;
  final Color background;
  final Color? borderColor;
  final Color? foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: borderColor != null
          ? CircleBorder(side: BorderSide(color: borderColor!, width: 1))
          : const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: icon),
        ),
      ),
    );
  }
}

/// Bottom "Don't have an account? Sign Up" footer link.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onTap,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            prompt,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: ColorsFrave.authInkSoft,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ColorsFrave.authAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
