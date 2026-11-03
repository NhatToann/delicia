import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../data/local_secure/secure_storage.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/user/user_bloc.dart';
import '../../components/app_bottom_nav.dart';
import '../../components/app_nav_destination.dart';
import '../../components/figma_header_band.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/modal_success.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _dateController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  final ImagePicker _imagePicker = ImagePicker();
  DateTime? _dateOfBirth;

  String? _loadedUid;

  static const int _maxProfileImageBytes = 1024 * 1024 * 2; // 2MB

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _dateController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) => DateFormat('dd / MM / yyyy').format(date);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'CHỌN NGÀY SINH',
      cancelText: 'Huỷ',
      confirmText: 'Xác nhận',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ColorsFrave.navOrange,
              onPrimary: Colors.white,
              surface: ColorsFrave.surfaceColor,
              onSurface: ColorsFrave.ink,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: ColorsFrave.navOrange,
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = picked;
      _dateController.text = _formatDate(picked);
    });
  }

  Future<void> _pickProfileImage(String uid) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (picked == null || !mounted) return;

      final fileSize = await picked.length();
      if (fileSize == 0 || fileSize > _maxProfileImageBytes) {
        if (mounted) errorTextSnack(context, context.l10n.profileImageTooLarge);
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      context.read<UserBloc>().add(
        OnUploadAvatarBytesEvent(
          uid: uid,
          bytes: bytes,
          mime: 'image/jpeg',
        ),
      );
    } catch (e) {
      if (mounted) errorTextSnack(context, context.l10n.profileImagePickFailed);
    }
  }

  void _saveProfile(String uid) {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      errorTextSnack(context, context.l10n.profileDateRequired);
      return;
    }

    final newFirstName = _firstNameController.text.trim();
    final newLastName = _lastNameController.text.trim();
    final newPhone = _phoneController.text.trim();
    final dateOfBirthStr = _dateOfBirth?.toIso8601String();

    // Chỉ cập nhật thông qua UserBloc
    context.read<UserBloc>().add(
      OnUpdateUserProfileEvent(
        uid: uid,
        firstName: newFirstName,
        lastName: newLastName,
        phone: newPhone,
        dateOfBirth: dateOfBirthStr,
      ),
    );

    // 2. Đồng thời cập nhật ngay lập tức vào AuthBloc để menu cam nhận diện được tên mới
    final authBloc = context.read<AuthBloc>();
    final currentUser = authBloc.state.user;
    if (currentUser != null) {
      final updatedAuthUser = currentUser.copyWith(
        firstName: newFirstName,
        lastName: newLastName,
        phone: newPhone,
        dateOfBirth: dateOfBirthStr,
      );
      authBloc.emit(authBloc.state.copyWith(user: updatedAuthUser));
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsFrave.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(context.l10n.profileSignOutTitle, style: FraveText.bold(20, color: ColorsFrave.ink)),
        content: Text(context.l10n.profileSignOutBody, style: FraveText.regular(14, color: ColorsFrave.greyText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.profileStaySignedIn, style: FraveText.medium(14, color: ColorsFrave.greyText)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ColorsFrave.errorColor, shape: const StadiumBorder()),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.profileSignOut, style: FraveText.medium(14, color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await SecureStorageFrave.instance.deleteSecureStorage();
    } catch (_) {}
    if (!context.mounted) return;
    context.read<AuthBloc>().add(LogOutEvent());
    context.read<UserBloc>().add(const OnClearUserProfileEvent());
    context.go('/intro');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth.user?.uid ?? '';

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
        children: [
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
                listenWhen: (previous, current) =>
                previous.lastSavedAt != current.lastSavedAt ||
                    previous.error != current.error,
                listener: (context, state) {
                  if (state.error != null) {
                    errorTextSnack(context, state.error!);
                  } else if (state.lastSavedAt != null) {
                    // Tải lại profile mới nhất
                    final uid = state.activeUid ?? '';
                    if (uid.isNotEmpty) {
                      context.read<UserBloc>().add(OnLoadUserProfileEvent(uid: uid));
                    }

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 60),
                            const SizedBox(height: 16),
                            Text(context.l10n.profileUpdated, style: FraveText.bold(16, color: ColorsFrave.ink)),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: ColorsFrave.navOrange,
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  context.go('/client/home');
                                },
                                child: const Text('Xong', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }


                  if (state.error != null) {
                    errorTextSnack(context, state.error!);
                  } else if (state.lastSavedAt != null) {
                    // Nếu là hành động lưu profile thành công thì bật popup thông báo chuyển hướng
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 60),
                            const SizedBox(height: 16),
                            Text(context.l10n.profileUpdated, style: FraveText.bold(16, color: ColorsFrave.ink)),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: ColorsFrave.navOrange,
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  context.go('/client/home');
                                },
                                child: const Text('Xong', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  final user = state.user;
                  if (user != null) {
                    if (_firstNameController.text.isEmpty) {
                      _firstNameController.text = user.firstName;
                    }
                    if (_lastNameController.text.isEmpty) {
                      _lastNameController.text = user.lastName;
                    }
                    if (_phoneController.text.isEmpty) {
                      _phoneController.text = user.phone ?? '';
                    }
                    if (_emailController.text.isEmpty) {
                      _emailController.text = user.email;
                    }
                    if (_dateOfBirth == null && user.dateOfBirth != null) {
                      _dateOfBirth = DateTime.tryParse(user.dateOfBirth!);
                      if (_dateOfBirth != null) {
                        _dateController.text = _formatDate(_dateOfBirth!);
                      }
                    }
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProfileAvatar(
                                image: user?.image,
                                avatarBytes: state.avatarBytes,
                                isUploading: state.isUploadingAvatar,
                                onTap: () => _pickProfileImage(uid),
                              ),
                              const SizedBox(height: 24),
                              _ProfileField(
                                label: context.l10n.profileFirstName,
                                controller: _firstNameController,
                                validator: (v) => (v == null || v.trim().isEmpty) ? context.l10n.profileFirstNameRequired : null,
                              ),
                              const SizedBox(height: 12),
                              _ProfileField(
                                label: context.l10n.profileLastName,
                                controller: _lastNameController,
                                validator: (v) => (v == null || v.trim().isEmpty) ? context.l10n.profileLastNameRequired : null,
                              ),
                              const SizedBox(height: 12),
                              _ProfileField(
                                label: context.l10n.profileDateOfBirth,
                                controller: _dateController,
                                readOnly: true,
                                onTap: _pickDate,
                                suffixIcon: const Icon(Icons.calendar_month_outlined, size: 18, color: ColorsFrave.greyText),
                              ),
                              const SizedBox(height: 12),
                              _ProfileField(
                                label: context.l10n.profileEmail,
                                controller: _emailController,
                                readOnly: true,
                              ),
                              const SizedBox(height: 12),
                              _ProfileField(
                                label: context.l10n.profilePhoneNumber,
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 24),
                              _ActionBtn(
                                label: state.isSaving ? context.l10n.profileSaving : context.l10n.profileSaveChanges,
                                background: ColorsFrave.navOrange,
                                foreground: Colors.white,
                                icon: Icons.check,
                                onPressed: state.isSaving ? null : () => _saveProfile(uid),
                              ),
                              const SizedBox(height: 12),
                              _ActionBtn(
                                label: context.l10n.profileManageAddresses,
                                background: ColorsFrave.pillYellow,
                                foreground: ColorsFrave.ink,
                                icon: Icons.location_on_outlined,
                                onPressed: () => context.push('/client/profile/addresses'),
                              ),
                              const SizedBox(height: 12),
                              _ActionBtn(
                                label: context.l10n.profileSignOut,
                                background: ColorsFrave.errorColor,
                                foreground: Colors.white,
                                icon: Icons.logout,
                                onPressed: uid.isEmpty ? null : () => _logout(context),
                              ),
                            ],
                          ),
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
      bottomNavigationBar: AppBottomNav(
        currentIndex: AppNavDestination.home,
        onTap: (index) {
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
        },
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.image,
    this.avatarBytes,
    required this.isUploading,
    required this.onTap,
  });

  final String? image;
  final Uint8List? avatarBytes;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: isUploading ? null : onTap,
              child: ClipOval(
                child: avatarBytes != null && avatarBytes!.isNotEmpty
                    ? Image.memory(avatarBytes!, fit: BoxFit.cover)
                    : (image == null || image!.trim().isEmpty)
                    ? Image.asset('assets/figma_home/profile_avatar.png', fit: BoxFit.cover)
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
              onTap: isUploading ? null : onTap,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorsFrave.navOrange,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: ColorsFrave.pageBg, width: 2),
                ),
                child: isUploading
                    ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.camera_alt_outlined, size: 15, color: Colors.white),
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
    this.validator,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
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
        child: TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          validator: validator,
          style: FraveText.regular(14, color: ColorsFrave.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: ColorsFrave.pillYellow,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: ColorsFrave.navOrange, width: 1),
            ),
          ),
        ),
      ),
    ],
  );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
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
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        shape: const StadiumBorder(),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: FraveText.semiBold(14, color: foreground)),
    ),
  );
}