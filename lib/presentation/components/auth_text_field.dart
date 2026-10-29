import 'package:flutter/material.dart';

import '../themes/colors_frave.dart';

/// Auth screen input field — pill-shaped outlined field matching the
/// 2-A / 2-B / 2-C UI kit: dark brown border, soft cream surface, optional
/// leading icon, single-line text.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;

  /// Placeholder shown above the user input (not used in the kit but kept
  /// available for accessibility / overflow).
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: ColorsFrave.authInk,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ColorsFrave.lightGrey,
        ),
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: ColorsFrave.authInk)
            : null,
        suffixIcon: suffix,
        // Padding is balanced so prefix icon and text align.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        // Fill: solid cream — matches the field surface in the kit.
        filled: true,
        fillColor: ColorsFrave.surfaceColor,
        // Pill-shaped border with a dark-brown stroke (the kit uses a
        // single colour, no focused/error variants).  A thin border keeps
        // the form calm; focus is signalled by the prefix icon colour.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusFrave.field),
          borderSide: const BorderSide(
            color: ColorsFrave.authInputBorder,
            width: 1.4,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusFrave.field),
          borderSide: const BorderSide(
            color: ColorsFrave.authInputBorder,
            width: 1.4,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusFrave.field),
          borderSide: const BorderSide(
            color: ColorsFrave.authAccent,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusFrave.field),
          borderSide: const BorderSide(
            color: ColorsFrave.errorColor,
            width: 1.4,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusFrave.field),
          borderSide: const BorderSide(
            color: ColorsFrave.errorColor,
            width: 1.6,
          ),
        ),
        errorStyle: const TextStyle(
          fontSize: 12,
          color: ColorsFrave.errorColor,
        ),
      ),
    );
  }
}

/// Visual label rendered *inside* the field (above the user input). The kit
/// uses placeholder-style labels at the very top of each pill; this widget
/// is rendered as the prefix icon area's caption, *outside* the field.
class FieldCaption extends StatelessWidget {
  const FieldCaption(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ColorsFrave.authInk,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
