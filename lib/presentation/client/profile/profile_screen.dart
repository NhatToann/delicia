import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/local_secure/secure_storage.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/user/user_bloc.dart';
import '../../components/figma_header_band.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';

/// ProfileScreen — main entry point for the client's profile (UC-06).
///
/// Figma node 133:380 ("4.1.1-I — My Profile"):
///
///   header band   yellow #F5CB58, back chevron left, "Hồ sơ của tôi"
///                 centred (League Spartan Bold 22 #F8F8F8)
///   body          light surface #F8F8F8, rounded top corners r30
///   avatar        120 x 120 circle + camera badge, centred
///   fields        full name / date of birth / email / phone, each a
///                 42 px pill in "Yellow 2" #F3E9B5
///   CTA           "Cập nhật hồ sơ" — orange stadium button
///
/// The screen shows the authenticated user's name, email, phone and avatar,
/// plus shortcuts to the address list and a sign-out button.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _seeded = false;
  String? _loadedUid;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth.user?.uid ?? '';
    if (kDebugMode) {
      debugPrint('[ProfileScreen] auth.user=${auth.user} uid="$uid" '
          'rolId="${auth.rolId}"');
    }
    if (uid.isNotEmpty && _loadedUid != uid) {
      _loadedUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<UserBloc>().add(OnLoadUserProfileEvent(uid: uid));
        context.read<UserBloc>().add(OnWatchUserProfileEvent(uid: uid));
      });
    }

    return Scaffold(
      backgroundColor: ColorsFrave.headerYellow,
      body: Column(
        children: <Widget>[
          FigmaHeaderBand(
            title: context.l10n.profileMyProfile,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/client/home');
              }
            },
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: ColorsFrave.pageBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              clipBehavior: Clip.antiAlias,
              child: BlocConsumer<UserBloc, UserState>(
                listenWhen: (a, b) =>
                    a.error != b.error ||
                    (a.lastSavedAt != b.lastSavedAt && b.lastSavedAt != null),
                listener: (_, state) {
                  if (state.error != null) {
                    errorTextSnack(context, state.error!);
                  } else if (state.lastSavedAt != null) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.profileUpdated),
                          backgroundColor: ColorsFrave.successColor,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                  }
                },
                builder: (context, state) {
                  final user = state.user;
                  if (!_seeded && user != null) {
                    _firstName.text = user.firstName;
                    _lastName.text = user.lastName;
                    _phone.text = user.phone ?? '';
                    _email.text = auth.user?.email ?? user.email;
                    _seeded = true;
                  }
                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 52,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _AvatarSection(
                              imageUrl: user?.image,
                              avatarBytes: state.avatarBytes,
                              isUploading: state.isUploadingAvatar,
                              onChange: () => _pickAvatar(context, uid),
                            ),
                            const SizedBox(height: 26),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  _Field(
                                    label: context.l10n.profileFirstName,
                                    controller: _firstName,
                                    hintText: context.l10n.profileFirstName,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? context.l10n.profileFirstNameRequired
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _Field(
                                    label: context.l10n.profileLastName,
                                    controller: _lastName,
                                    hintText: context.l10n.profileLastName,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? context.l10n.profileLastNameRequired
                                        : null,
                                  ),
                                  const SizedBox(height: 14),
                                  _Field(
                                    label: context.l10n.profileEmail,
                                    controller: _email,
                                    hintText: 'email@example.com',
                                    readOnly: true,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  const SizedBox(height: 14),
                                  _Field(
                                    label: context.l10n.profilePhoneNumber,
                                    controller: _phone,
                                    hintText: '+84 912 345 678',
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            _StadiumButton(
                              label: state.isSaving
                                  ? context.l10n.profileSaving
                                  : context.l10n.profileSaveChanges,
                              background: ColorsFrave.navOrange,
                              foreground: ColorsFrave.onOrange,
                              icon: Icons.check,
                              onPressed: state.isSaving
                                  ? null
                                  : () => _save(context, uid),
                            ),
                            const SizedBox(height: 12),
                            _StadiumButton(
                              label: context.l10n.profileManageAddresses,
                              background: ColorsFrave.pillYellow,
                              foreground: ColorsFrave.ink,
                              icon: Icons.location_on_outlined,
                              onPressed: () =>
                                  context.push('/client/profile/addresses'),
                            ),
                            const SizedBox(height: 12),
                            _StadiumButton(
                              label: context.l10n.profileFullProfileDetails,
                              background: ColorsFrave.pillYellow,
                              foreground: ColorsFrave.ink,
                              icon: Icons.badge_outlined,
                              onPressed: () =>
                                  context.push('/client/profile/edit'),
                            ),
                            const SizedBox(height: 12),
                            _StadiumButton(
                              label: context.l10n.profileSignOut,
                              background: ColorsFrave.errorColor,
                              foreground: ColorsFrave.onOrange,
                              icon: Icons.logout,
                              onPressed: uid.isEmpty
                                  ? null
                                  : () => _logout(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context, String uid) async {
    if (uid.isEmpty) {
      errorTextSnack(context, context.l10n.profileSignInRequired);
      return;
    }
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked == null || !context.mounted) return;
      context.read<UserBloc>().add(
        OnUploadAvatarEvent(uid: uid, file: File(picked.path)),
      );
    } catch (e) {
      if (context.mounted) {
        errorTextSnack(context, context.l10n.profileImagePickFailed);
      }
    }
  }

  Future<void> _save(BuildContext context, String uid) async {
    if (uid.isEmpty) {
      errorTextSnack(context, context.l10n.profileSignInRequired);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    context.read<UserBloc>().add(
      OnUpdateUserProfileEvent(
        uid: uid,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phone: _phone.text.trim(),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsFrave.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusFrave.sheet),
        ),
        title: Text(
          context.l10n.profileSignOutTitle,
          style: FraveText.bold(20, color: ColorsFrave.ink),
        ),
        content: Text(
          context.l10n.profileSignOutBody,
          style: FraveText.regular(14, color: ColorsFrave.greyText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              context.l10n.profileStaySignedIn,
              style: FraveText.medium(14, color: ColorsFrave.greyText),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ColorsFrave.errorColor,
              foregroundColor: ColorsFrave.onOrange,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.l10n.profileSignOut,
              style: FraveText.medium(14, color: ColorsFrave.onOrange),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // Clear cached credentials then sign out through the auth bloc.
    // A storage failure must never block the sign-out — the user has to be
    // able to leave the account even if the local cache can't be cleared.
    try {
      await SecureStorageFrave.instance.deleteSecureStorage();
    } catch (_) {
      // Ignored on purpose: the auth sign-out below is what matters.
    }
    if (!context.mounted) return;
    context.read<AuthBloc>().add(LogOutEvent());
    // Reset profile state so a subsequent sign-in starts clean.
    context.read<UserBloc>().add(const OnClearUserProfileEvent());
    if (context.mounted) context.go('/intro');
  }
}

/// The avatar with its camera badge — Figma: 120 x 120, r9 badge.
class _AvatarSection extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? avatarBytes;
  final bool isUploading;
  final VoidCallback onChange;

  const _AvatarSection({
    required this.imageUrl,
    this.avatarBytes,
    required this.isUploading,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: ColorsFrave.orangeSoft,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: _avatarImage(),
              ),
              Positioned(
                right: -5,
                bottom: -5,
                child: Semantics(
                  button: true,
                  label: context.l10n.profileChoosePhoto,
                  child: InkWell(
                    onTap: isUploading ? null : onChange,
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: ColorsFrave.navOrange,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: ColorsFrave.pageBg,
                          width: 2,
                        ),
                      ),
                      child: isUploading
                          ? const Padding(
                              padding: EdgeInsets.all(6),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ColorsFrave.onOrange,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              color: ColorsFrave.onOrange,
                              size: 15,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isUploading
                ? context.l10n.profileUploading
                : context.l10n.profileAvatarHint,
            style: FraveText.regular(13, color: ColorsFrave.greyText),
          ),
        ],
      ),
    );
  }

  /// Renders the avatar: inline bytes first (Realtime Database fallback),
  /// then the remote URL, then the default placeholder icon.
  Widget _avatarImage() {
    final bytes = avatarBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: 120,
        height: 120,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholderIcon(),
      );
    }
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholderIcon();
    }
    return ImageResolver.resolveWidget(
      imageUrl!,
      fit: BoxFit.cover,
      width: 120,
      height: 120,
      fallback: 'assets/figma_home/profile_avatar.png',
    );
  }

  Widget _placeholderIcon() => const Icon(
    Icons.person,
    size: 60,
    color: ColorsFrave.navOrange,
  );
}

/// A labelled pill-shaped input — Figma: 42 px tall, r15, "Yellow 2" fill.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hintText,
    this.readOnly = false,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: FraveText.medium(14, color: ColorsFrave.ink),
          ),
        ),
        SizedBox(
          height: 42,
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            validator: validator,
            style: FraveText.regular(14, color: ColorsFrave.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: ColorsFrave.pillYellow,
              hintText: hintText,
              hintStyle: FraveText.regular(13, color: ColorsFrave.greyText),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: ColorsFrave.errorColor,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: ColorsFrave.errorColor,
                  width: 1,
                ),
              ),
              errorStyle: FraveText.regular(11, color: ColorsFrave.errorColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// A full-width stadium button used for the primary / secondary actions.
class _StadiumButton extends StatelessWidget {
  const _StadiumButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.45),
          disabledForegroundColor: foreground.withValues(alpha: 0.8),
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        icon: Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: FraveText.semiBold(14, color: foreground),
          ),
        ),
      ),
    );
  }
}
