import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../components/app_bottom_nav.dart';
import '../../components/app_nav_destination.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/modal_success.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _dateController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final ImagePicker _imagePicker = ImagePicker();
  DateTime? _dateOfBirth;
  Uint8List? _selectedImageBytes;
  String? _selectedImageContentType;

  static const int _maxProfileImageBytes = 1024 * 1024;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _dateOfBirth = DateTime.tryParse(user?.dateOfBirth ?? '');
    _dateController = TextEditingController(
      text: _dateOfBirth == null ? '' : _formatDate(_dateOfBirth!),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      DateFormat('dd / MM / yyyy').format(date);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final currentDate = _dateOfBirth;
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate != null && !currentDate.isAfter(now)
          ? currentDate
          : DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme
              .copyWith(primary: ColorsFrave.navOrange),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = picked;
      _dateController.text = _formatDate(picked);
    });
  }

  Future<void> _pickProfileImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null || !mounted) return;

      final fileSize = await picked.length();
      if (!mounted) return;
      if (fileSize == 0) {
        errorTextSnack(context, context.l10n.profileImageInvalid);
        return;
      }
      if (fileSize > _maxProfileImageBytes) {
        errorTextSnack(context, context.l10n.profileImageTooLarge);
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final contentType = _imageContentType(bytes);
      if (bytes.length > _maxProfileImageBytes) {
        errorTextSnack(context, context.l10n.profileImageTooLarge);
        return;
      }
      final decodable = contentType != null && await _canDecodeImage(bytes);
      if (!mounted) return;
      if (!decodable) {
        errorTextSnack(context, context.l10n.profileImageInvalid);
        return;
      }
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageContentType = contentType;
      });
    } on MissingPluginException catch (error) {
      debugPrint('ImagePicker plugin is unavailable: $error');
      if (mounted) {
        errorTextSnack(context, context.l10n.profileImagePluginRestartRequired);
      }
    } on PlatformException catch (error, stackTrace) {
      debugPrint('ImagePicker failed (${error.code}): ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        errorTextSnack(context, context.l10n.profileImagePickFailed);
      }
    } catch (error, stackTrace) {
      debugPrint('Profile image selection failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        errorTextSnack(context, context.l10n.profileImagePickFailed);
      }
    }
  }

  static String? _imageContentType(Uint8List bytes) {
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

  static Future<bool> _canDecodeImage(Uint8List bytes) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1600,
        targetHeight: 1600,
      );
      image = (await codec.getNextFrame()).image;
      return image.width > 0 && image.height > 0;
    } catch (_) {
      return false;
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  void _saveProfile() {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) {
      errorTextSnack(context, context.l10n.profileSignInRequired);
      return;
    }

    final fullName = _nameController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final namePattern = RegExp(r"^[A-Za-zÀ-ỹ]+(?:[ '-][A-Za-zÀ-ỹ]+)*$");
    if (fullName.isEmpty) {
      errorTextSnack(context, context.l10n.profileNameRequired);
      return;
    }
    if (fullName.length < 2 || !namePattern.hasMatch(fullName)) {
      errorTextSnack(context, context.l10n.profileNameInvalid);
      return;
    }
    final parts = fullName.split(' ');
    if (_dateOfBirth == null) {
      errorTextSnack(context, context.l10n.profileDateRequired);
      return;
    }
    final now = DateTime.now();
    if (_dateOfBirth!.isAfter(now) || _dateOfBirth!.year < 1900) {
      errorTextSnack(context, context.l10n.profileDateInvalid);
      return;
    }
    final email = _emailController.text.trim();
    if (!RegExp(
      r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
      caseSensitive: false,
    ).hasMatch(email)) {
      errorTextSnack(context, context.l10n.profileEmailInvalid);
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      errorTextSnack(context, context.l10n.profilePhoneRequired);
      return;
    }
    final normalizedPhone = phone.replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^(?:0\d{8,10}|\+?[1-9]\d{7,14})$')
        .hasMatch(normalizedPhone)) {
      errorTextSnack(context, context.l10n.profilePhoneInvalid);
      return;
    }

    context.read<AuthBloc>().add(
      UpdateProfileEvent(
        firstName: parts.first,
        lastName: parts.skip(1).join(' '),
        phone: normalizedPhone,
        dateOfBirth: DateFormat('yyyy-MM-dd').format(_dateOfBirth!),
        profileImageBytes: _selectedImageBytes,
        profileImageContentType: _selectedImageContentType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.profileUpdateVersion != current.profileUpdateVersion ||
          (previous.profileUpdateError == null &&
              current.profileUpdateError != null),
      listener: (context, state) {
        final error = state.profileUpdateError;
        if (error != null) {
          errorMessageSnack(context, error);
        } else {
          setState(() {
            _selectedImageBytes = null;
            _selectedImageContentType = null;
          });
          modalSuccess(context, context.l10n.profileUpdated);
        }
      },
      builder: (context, state) {
        final user = state.user;
        return Scaffold(
          backgroundColor: ColorsFrave.headerYellow,
          body: Column(
            children: [
              _ProfileHeader(topInset: topInset),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: ColorsFrave.pageBg,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 44,
                        ),
                        child: Column(
                          children: [
                            _ProfileAvatar(
                              image: user?.image,
                              selectedBytes: _selectedImageBytes,
                              onTap: _pickProfileImage,
                            ),
                            const SizedBox(height: 24),
                            _ProfileField(
                              label: context.l10n.profileFullName,
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            _ProfileField(
                              label: context.l10n.profileDateOfBirth,
                              controller: _dateController,
                              readOnly: true,
                              onTap: _pickDate,
                              suffixIcon: const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: ColorsFrave.greyText,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ProfileField(
                              label: context.l10n.profileEmail,
                              controller: _emailController,
                              readOnly: true,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            _ProfileField(
                              label: context.l10n.profilePhoneNumber,
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 52),
                            SizedBox(
                              width: 157,
                              height: 38,
                              child: FilledButton(
                                onPressed: state.isUpdatingProfile == true
                                    ? null
                                    : _saveProfile,
                                style: FilledButton.styleFrom(
                                  backgroundColor: ColorsFrave.navOrange,
                                  disabledBackgroundColor: ColorsFrave.navOrange
                                      .withValues(alpha: 0.55),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                child: state.isUpdatingProfile == true
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        context.l10n.profileUpdateButton,
                                        maxLines: 1,
                                        style: FraveText.semiBold(
                                          14,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            currentIndex: AppNavDestination.home,
            onTap: _handleNavigationTap,
          ),
        );
      },
    );
  }

  void _handleNavigationTap(int index) {
    final router = GoRouter.of(context);
    Navigator.of(context).maybePop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = switch (index) {
        AppNavDestination.discover => '/client/search-category',
        AppNavDestination.orders => '/client/orders',
        AppNavDestination.tracking => '/client/map',
        _ => '/client/home',
      };
      router.go(location);
    });
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: topInset + 108,
    child: Stack(
      children: [
        Positioned(
          left: 22,
          top: topInset + 40,
          child: Semantics(
            button: true,
            label: context.l10n.actionBack,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 17,
                color: ColorsFrave.navOrange,
              ),
            ),
          ),
        ),
        Positioned(
          left: 72,
          right: 72,
          top: topInset + 48,
          child: Text(
            context.l10n.profileMyProfile,
            textAlign: TextAlign.center,
            style: FraveText.bold(22, color: ColorsFrave.onOrange),
          ),
        ),
      ],
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.image,
    required this.selectedBytes,
    required this.onTap,
  });

  final String? image;
  final Uint8List? selectedBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: context.l10n.profileChoosePhoto,
    child: SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: ClipOval(
                child: selectedBytes != null
                    ? Image.memory(selectedBytes!, fit: BoxFit.cover)
                    : image == null || image!.trim().isEmpty
                    ? Image.asset(
                        'assets/figma_home/profile_avatar.png',
                        fit: BoxFit.cover,
                      )
                    : ImageResolver.resolveWidget(
                        image!,
                        fit: BoxFit.cover,
                        fallback: 'assets/figma_home/profile_avatar.png',
                      ),
              ),
            ),
          ),
          Positioned(
            right: -5,
            bottom: -5,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorsFrave.navOrange,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: ColorsFrave.pageBg, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    this.readOnly = false,
    this.onTap,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 7),
        child: Text(label, style: FraveText.medium(14, color: ColorsFrave.ink)),
      ),
      SizedBox(
        height: 42,
        child: TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: FraveText.regular(14, color: ColorsFrave.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: ColorsFrave.pillYellow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            suffixIcon: suffixIcon,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: ColorsFrave.navOrange,
                width: 1,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
