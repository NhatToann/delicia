import 'package:flutter/material.dart';

import '../themes/colors_frave.dart';

/// Material Design 3 Filled Button
class BtnFrave extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final double height;
  final double borderRadius;
  final bool isLoading;
  final IconData? icon;

  const BtnFrave({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor,
    this.height = 56,
    this.borderRadius = 28,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? ColorsFrave.primaryColor,
          foregroundColor: textColor ?? ColorsFrave.onPrimary,
          disabledBackgroundColor: (color ?? ColorsFrave.primaryColor).withValues(alpha: 0.4),
          disabledForegroundColor: textColor ?? ColorsFrave.onPrimary.withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    textColor ?? ColorsFrave.onPrimary,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Material Design 3 Outlined Button
class BtnOutlined extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Color? textColor;
  final double height;
  final double borderRadius;
  final IconData? icon;

  const BtnOutlined({
    super.key,
    required this.text,
    required this.onPressed,
    this.borderColor,
    this.textColor,
    this.height = 56,
    this.borderRadius = 28,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? ColorsFrave.primaryColor,
          side: BorderSide(
            color: borderColor ?? ColorsFrave.primaryColor,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: textColor ?? ColorsFrave.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Material Design 3 Tonal Button
class BtnTonal extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;
  final double borderRadius;
  final IconData? icon;

  const BtnTonal({
    super.key,
    required this.text,
    required this.onPressed,
    this.height = 56,
    this.borderRadius = 28,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ColorsFrave.primaryContainer,
          foregroundColor: ColorsFrave.onPrimaryContainer,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Material Design 3 Text Button
class BtnText extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? textColor;
  final IconData? icon;

  const BtnText({
    super.key,
    required this.text,
    required this.onPressed,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor ?? ColorsFrave.primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: 4),
          ],
          // The label is kept on a single line and scales down rather
          // than wrapping, so it never spills out of the button.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: textColor ?? ColorsFrave.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
