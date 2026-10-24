import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';

class FormFieldFrave extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? label;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final int? maxLines;

  const FormFieldFrave({
    super.key,
    required this.controller,
    required this.hintText,
    this.label,
    this.isPassword = false,
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
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      maxLines: isPassword ? 1 : maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

/// Canonical validators used by Auth screens.
final validatedEmail = EmailValidator(errorText: 'Enter a valid email');
final passwordValidator = MultiValidator([
  RequiredValidator(errorText: 'Password is required'),
  MinLengthValidator(6, errorText: 'Password must be at least 6 characters'),
]);
