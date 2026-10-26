import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/user/user_bloc.dart';
import '../../../data/local_secure/secure_storage.dart';
import '../../components/btn_frave.dart';
import '../../components/form_field_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../themes/colors_frave.dart';

/// ProfileScreen — main entry point for the client's profile (UC-06).
///
/// Shows the authenticated user's:
///   - first / last name (editable)
///   - email (read-only, sourced from AuthBloc)
///   - phone (editable)
///   - avatar (Firebase Storage backed)
///
/// Plus shortcuts to the address list and a logout button.
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
  final ImagePicker _picker = ImagePicker();

  bool _seeded = false;
  String? _loadedUid;

  @override
  void initState() {
    super.initState();
    // No fetch here — the build() method reacts to AuthBloc state changes
    // and kicks off the load once the user is available.
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/client/home');
            }
          },
        ),
        title: const TextCustom('My Profile', fontWeight: FontWeight.bold),
        centerTitle: true,
      ),
      body: BlocConsumer<UserBloc, UserState>(
        listenWhen: (a, b) =>
            a.error != b.error ||
            (a.lastSavedAt != b.lastSavedAt && b.lastSavedAt != null),
        listener: (_, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
          } else if (state.lastSavedAt != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Profile updated'),
                  backgroundColor: ColorsFrave.successColor,
                  duration: Duration(seconds: 2),
                ),
              );
          }
        },
        builder: (context, state) {
          if (!_seeded && state.user != null) {
            _firstName.text = state.user!.firstName;
            _lastName.text = state.user!.lastName;
            _phone.text = state.user!.phone ?? '';
            _seeded = true;
          }
          final user = state.user;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AvatarSection(
                imageUrl: user?.image,
                avatarBytes: state.avatarBytes,
                isUploading: state.isUploadingAvatar,
                onChange: () => _pickAvatar(context, uid),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    const _LabelText('First name'),
                    const SizedBox(height: 6),
                    FormFieldFrave(
                      controller: _firstName,
                      hintText: 'First name',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'First name is required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const _LabelText('Last name'),
                    const SizedBox(height: 6),
                    FormFieldFrave(
                      controller: _lastName,
                      hintText: 'Last name',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Last name is required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const _LabelText('Email'),
                    const SizedBox(height: 6),
                    FormFieldFrave(
                      controller:
                          TextEditingController(
                              text: auth.user?.email ?? user?.email ?? '',
                            )
                            ..selection = TextSelection.collapsed(
                              offset: (auth.user?.email ?? user?.email ?? '')
                                  .length,
                            ),
                      hintText: 'email@example.com',
                      readOnly: true,
                    ),
                    const SizedBox(height: 14),
                    const _LabelText('Phone number'),
                    const SizedBox(height: 6),
                    FormFieldFrave(
                      controller: _phone,
                      hintText: '+1 555 123 4567',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              BtnFrave(
                text: state.isSaving ? 'Saving…' : 'Save changes',
                onPressed: state.isSaving ? null : () => _save(context, uid),
              ),
              const SizedBox(height: 14),
              BtnFrave(
                text: 'Manage addresses',
                color: Colors.white,
                textColor: ColorsFrave.primaryColor,
                onPressed: () => context.push('/client/profile/addresses'),
              ),
              const SizedBox(height: 14),
              BtnFrave(
                text: 'Sign out',
                color: ColorsFrave.errorColor,
                onPressed: uid.isEmpty ? null : () => _logout(context),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context, String uid) async {
    if (uid.isEmpty) {
      errorMessageSnack(context, 'Sign in to change your avatar.');
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
        errorMessageSnack(context, 'Could not open gallery: $e');
      }
    }
  }

  Future<void> _save(BuildContext context, String uid) async {
    if (uid.isEmpty) {
      errorMessageSnack(context, 'Sign in to update your profile.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    context.read<UserBloc>().add(
      OnUpdateUserProfileEvent(
        uid: uid,
        firstName: _firstName.text,
        lastName: _lastName.text,
        phone: _phone.text,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const TextCustom('Sign out?', fontWeight: FontWeight.bold),
        content: const TextCustom(
          'You will need to sign in again to use the app.',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TextCustom('Stay', color: ColorsFrave.greyText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
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
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: ColorsFrave.backgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 8),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _avatarImage(),
              ),
              Positioned(
                child: InkWell(
                  onTap: isUploading ? null : onChange,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: ColorsFrave.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: isUploading
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextCustom(
            isUploading ? 'Uploading…' : 'Tap to change avatar',
            color: ColorsFrave.greyText,
            fontSize: 13,
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
        width: 110,
        height: 110,
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
      width: 110,
      height: 110,
    );
  }

  Widget _placeholderIcon() => const Icon(
        Icons.person,
        size: 56,
        color: ColorsFrave.primaryColor,
      );
}

class _LabelText extends StatelessWidget {
  final String text;
  const _LabelText(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextCustom(text, fontWeight: FontWeight.w600),
    );
  }
}
