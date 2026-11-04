import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../helpers/l10n_extension.dart';
import '../../../helpers/image_resolver.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The image picker of the admin forms (UC-08).
///
/// The admin picks the catalogue photo from the gallery; the bytes stay
/// in memory until the form is saved, and the upload itself is done by
/// the bloc (so the presentation layer never talks to Firebase).
///
/// The widget shows the picked photo (or the existing one) with a
/// camera badge, exactly like the profile avatar — the admin knows at a
/// glance which photo will be saved.
class AdminImagePicker extends StatefulWidget {
  const AdminImagePicker({
    super.key,
    required this.onPicked,
    this.existingUrl = '',
    this.label = '',
    this.size = 120,
    this.maxBytes = 2 * 1024 * 1024,
    this.onError,
  });

  /// Fired with the picked bytes. The content type is derived from the
  /// bytes themselves (JPEG / PNG / WebP).
  final void Function(Uint8List bytes, String contentType) onPicked;

  /// The picture the row already has — a URL or an asset path.
  final String existingUrl;

  /// The label above the picker.
  final String label;

  /// The width / height of the preview tile.
  final double size;

  /// The largest accepted file, in bytes.
  final int maxBytes;

  /// Fired with a translated message when the pick failed.
  final void Function(String message)? onError;

  @override
  State<AdminImagePicker> createState() => _AdminImagePickerState();
}

class _AdminImagePickerState extends State<AdminImagePicker> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _bytes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label.isNotEmpty) ...<Widget>[
          Text(
            widget.label,
            style: FraveText.medium(14, color: ColorsFrave.ink),
          ),
          const SizedBox(height: 8),
        ],
        Semantics(
          button: true,
          label: l10n.adminCategoryChooseImage,
          child: GestureDetector(
            onTap: _pick,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(RadiusFrave.card),
                      child: _preview(),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ColorsFrave.navOrange,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: ColorsFrave.pageBg,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        size: 17,
                        color: ColorsFrave.onOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _preview() {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    if (widget.existingUrl.trim().isNotEmpty) {
      return ImageResolver.resolveWidget(
        widget.existingUrl,
        fit: BoxFit.cover,
        fallback: 'assets/icons/no-data.svg',
      );
    }
    return Container(
      color: ColorsFrave.surfaceVariant,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 32,
        color: ColorsFrave.greyText,
      ),
    );
  }

  Future<void> _pick() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;

      final fileSize = await picked.length();
      if (!mounted) return;
      if (fileSize == 0) {
        _fail(context.l10n.adminCategoryImageInvalid);
        return;
      }
      if (fileSize > widget.maxBytes) {
        _fail(context.l10n.adminCategoryImageTooLarge);
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.length > widget.maxBytes) {
        _fail(context.l10n.adminCategoryImageTooLarge);
        return;
      }

      final contentType = contentTypeOf(bytes);
      if (contentType == null) {
        _fail(context.l10n.adminCategoryImageInvalid);
        return;
      }

      setState(() => _bytes = bytes);
      widget.onPicked(bytes, contentType);
    } on MissingPluginException {
      if (mounted) _fail(context.l10n.adminCategoryImagePickFailed);
    } on PlatformException {
      if (mounted) _fail(context.l10n.adminCategoryImagePickFailed);
    } catch (_) {
      if (mounted) _fail(context.l10n.adminCategoryImagePickFailed);
    }
  }

  void _fail(String message) {
    final onError = widget.onError;
    if (onError != null) {
      onError(message);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Detects the content type of [bytes].
///
/// Returns `null` when the bytes are not a JPEG, PNG or WebP image —
/// the caller turns that into a translated error message.
String? contentTypeOf(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  const pngSignature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length >= pngSignature.length) {
    var isPng = true;
    for (var i = 0; i < pngSignature.length; i++) {
      if (bytes[i] != pngSignature[i]) {
        isPng = false;
        break;
      }
    }
    if (isPng) return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}
