import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';

import '../helpers/l10n_extension.dart';
import '../themes/colors_frave.dart';

/// Material Design 3 Filled Text Field
class FormFieldFrave extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? label;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final int? maxLines;
  final VoidCallback? onSuffixTap;
  final bool autofocus;

  const FormFieldFrave({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.readOnly = false,
    this.maxLines = 1,
    this.onSuffixTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      maxLines: isPassword ? 1 : maxLines,
      onChanged: onChanged,
      autofocus: autofocus,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: ColorsFrave.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: ColorsFrave.greyText.withValues(alpha: 0.7),
          fontWeight: FontWeight.w400,
        ),
        labelText: label,
        labelStyle: const TextStyle(
          color: ColorsFrave.greyText,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: ColorsFrave.primaryColor,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: ColorsFrave.greyText, size: 22)
            : null,
        suffixIcon: suffixIcon != null || isPassword
            ? IconButton(
                icon: Icon(
                  suffixIcon ?? (isPassword ? Icons.visibility_off : null),
                  color: ColorsFrave.greyText,
                  size: 22,
                ),
                onPressed: onSuffixTap,
              )
            : null,
        filled: true,
        fillColor: ColorsFrave.surfaceVariant.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ColorsFrave.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ColorsFrave.errorColor,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ColorsFrave.errorColor,
            width: 2,
          ),
        ),
        errorStyle: const TextStyle(
          color: ColorsFrave.errorColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Material Design 3 Outlined Text Field
class FormFieldOutlined extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? label;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final int? maxLines;

  const FormFieldOutlined({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.onChanged,
    this.readOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: ColorsFrave.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: ColorsFrave.greyText.withValues(alpha: 0.7),
          fontWeight: FontWeight.w400,
        ),
        labelText: label,
        labelStyle: const TextStyle(
          color: ColorsFrave.greyText,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: ColorsFrave.primaryColor,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: ColorsFrave.greyText, size: 22)
            : null,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ColorsFrave.outline,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ColorsFrave.outline,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ColorsFrave.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ColorsFrave.errorColor,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ColorsFrave.errorColor,
            width: 2,
          ),
        ),
        errorStyle: const TextStyle(
          color: ColorsFrave.errorColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Canonical validators used by Auth screens.
///
/// The messages come from the Vietnamese ARB so the form layer speaks the
/// same language as the screens that host it.
final validatedEmail = EmailValidator(errorText: viL10n.validationEmailInvalid);
final passwordValidator = MultiValidator([
  RequiredValidator(errorText: viL10n.validationPasswordRequired),
  MinLengthValidator(6, errorText: viL10n.validationPasswordTooShort),
]);
