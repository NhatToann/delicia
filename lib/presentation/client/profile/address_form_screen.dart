import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/address/address_bloc.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/models/client_address.dart';
import '../../../data/services/vietnam_geo_resolver.dart';
import '../../components/figma_header_band.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';

class AddressFormScreen extends StatefulWidget {
  final ClientAddress? existingAddress;

  const AddressFormScreen({super.key, this.existingAddress});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _street;
  late final TextEditingController _reference;
  late bool _isDefault;
  late String _editingId;
  /// The resolver over the bundled Vietnamese administrative dataset.
  ///
  /// The 2025 reform dropped the district level, so the picker offers
  /// *province -> ward* and every ward carries a real centroid.
  final VietnamGeoResolver _resolver = VietnamGeoResolver.instance;

  String? _selectedCity;
  String? _selectedWard;

  /// The province names, loaded asynchronously from the dataset.
  List<String> _provinceNames = const <String>[];

  @override
  void initState() {
    super.initState();
    final a = widget.existingAddress;
    if (a != null && a.street.isNotEmpty) {
      // Chi lay phan ten duong/so nha dau tien truoc dau phay de tranh don rac phuong/quan cu
      final streetOnly = a.street.split(',').first.trim();
      _street = TextEditingController(text: streetOnly);
    } else {
      _street = TextEditingController(text: '');
    }

    _reference = TextEditingController(text: a?.reference ?? '');
    _isDefault = a?.isDefault ?? false;
    _editingId = a?.id ?? '';

    _loadProvinces();
  }

  /// Loads the province list and pre-selects the first one.
  Future<void> _loadProvinces() async {
    await _resolver.ensureLoaded();
    if (!mounted) return;
    final provinces = _resolver.provinces.map((p) => p.name).toList();
    setState(() {
      _provinceNames = provinces;
      _selectedCity = provinces.isEmpty ? null : provinces.first;
      _selectedWard = _firstWardOf(_selectedCity);
    });
  }

  /// The first ward of a province, or `null` when the province is empty.
  String? _firstWardOf(String? province) {
    if (province == null) return null;
    final wards = _resolver.wardsOf(province);
    return wards.isEmpty ? null : wards.first.name;
  }

  @override
  void dispose() {
    _street.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _openSelectorModal({
    required String title,
    required List<String> items,
    required String? selectedItem,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: FraveText.semiBold(16, color: ColorsFrave.ink)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = item == selectedItem;
                    return ListTile(
                      title: Text(
                        item,
                        style: FraveText.regular(
                          14,
                          color: isSelected ? ColorsFrave.navOrange : ColorsFrave.ink,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: ColorsFrave.navOrange, size: 18)
                          : null,
                      onTap: () {
                        onSelected(item);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingAddress != null;
    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      body: BlocConsumer<AddressBloc, AddressState>(
        listener: (context, state) {
          if (state.error != null) {
            errorTextSnack(context, state.error!);
          }
        },
        builder: (context, state) {
          return Column(
            children: <Widget>[
              FigmaHeaderBand(
                title: isEditing
                    ? context.l10n.addressEdit
                    : context.l10n.addressAdd,
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/client/home');
                  }
                },
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _buildSelectorField(
                              label: 'Tỉnh / Thành phố',
                              value: _selectedCity ?? 'Chọn Tỉnh/Thành phố',
                              onTap: () {
                                _openSelectorModal(
                                  title: 'Chọn Tỉnh / Thành phố',
                                  items: _provinceNames,
                                  selectedItem: _selectedCity,
                                  onSelected: (val) {
                                    setState(() {
                                      _selectedCity = val;
                                      // The 2025 reform dropped the
                                      // district level, so picking a
                                      // province resets the ward to its
                                      // first entry.
                                      _selectedWard = _firstWardOf(val);
                                    });
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildSelectorField(
                              label: 'Phường / Xã',
                              value: _selectedWard ?? 'Chọn Phường/Xã',
                              onTap: () {
                                final List<String> wards = _selectedCity == null
                                    ? const <String>[]
                                    : _resolver
                                          .wardsOf(_selectedCity!)
                                          .map((w) => w.name)
                                          .toList();
                                _openSelectorModal(
                                  title: 'Chọn Phường / Xã',
                                  items: wards,
                                  selectedItem: _selectedWard,
                                  onSelected: (val) {
                                    setState(() {
                                      _selectedWard = val;
                                    });
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            _Field(
                              label: context.l10n.addressStreet,
                              controller: _street,
                              hintText: 'Ví dụ: 123 Lê Duẩn',
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? context.l10n.addressStreetRequired
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _Field(
                              label: context.l10n.addressReference,
                              controller: _reference,
                              hintText: 'Tòa nhà, số phòng, ghi chú thêm...',
                            ),
                            const SizedBox(height: 18),
                            _DefaultSwitch(
                              value: _isDefault,
                              onChanged: (v) =>
                                  setState(() => _isDefault = v),
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              height: 46,
                              child: FilledButton.icon(
                                onPressed: state.isMutating ? null : () => _submit(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: ColorsFrave.navOrange,
                                  foregroundColor: ColorsFrave.onOrange,
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                ),
                                icon: state.isMutating
                                    ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Icon(Icons.check, size: 18),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    state.isMutating
                                        ? 'Đang lưu...'
                                        : isEditing
                                        ? context.l10n.addressSaveChanges
                                        : context.l10n.addressSave,
                                    style: FraveText.semiBold(
                                      14,
                                      color: ColorsFrave.onOrange,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 46,
                              child: TextButton(
                                onPressed: state.isMutating ? null : () => context.pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: ColorsFrave.greyText,
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(
                                  context.l10n.addressCancel,
                                  style: FraveText.semiBold(
                                    14,
                                    color: ColorsFrave.greyText,
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
          );
        },
      ),
    );
  }

  Widget _buildSelectorField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
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
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: ColorsFrave.pillYellow,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: FraveText.regular(14, color: ColorsFrave.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: ColorsFrave.greyText, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final uid = context.read<AuthBloc>().state.user?.uid ?? '';
    if (uid.isEmpty) {
      errorTextSnack(context, context.l10n.profileSignInRequired);
      return;
    }

    final fullStreet = '${_street.text.trim()}, '
        '${_selectedWard ?? ""}, '
        '${_selectedCity ?? ""}';

    // Resolve the coordinates *before* saving: the delivery fee is
    // distance-based and the courier navigates to a point, so an address
    // stored at 0.0/0.0 would produce a zero fee and a broken route.
    final resolver = await _resolver.ensureLoaded();
    final point = resolver.resolve(
      ward: _selectedWard,
      province: _selectedCity,
    );

    final isEditing = _editingId.isNotEmpty;
    final bloc = context.read<AddressBloc>();

    if (!isEditing) {
      bloc.add(
        OnAddAddressEvent(
          uid: uid,
          address: ClientAddress(
            id: '',
            street: fullStreet,
            reference: _reference.text.trim(),
            latitude: point?.latitude ?? 0.0,
            longitude: point?.longitude ?? 0.0,
            isDefault: _isDefault,
          ),
        ),
      );
    } else {
      bloc.add(
        OnUpdateAddressEvent(
          uid: uid,
          address: ClientAddress(
            id: _editingId,
            street: fullStreet,
            reference: _reference.text.trim(),
            latitude: point?.latitude ?? 0.0,
            longitude: point?.longitude ?? 0.0,
            isDefault: _isDefault,
          ),
        ),
      );
    }

    // Tải lại danh sách địa chỉ ngay lập tức
    bloc.add(OnLoadAddressesEvent(uid: uid));

    // Hiển thị thông báo thành công
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Cập nhật địa chỉ thành công!' : 'Thêm địa chỉ mới thành công!'),
        backgroundColor: ColorsFrave.navOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 1000),
      ),
    );

    // Chờ 400ms để SnackBar hiện rõ rồi mới điều hướng về trang trước
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    if (context.canPop()) {
      context.pop(true);
    }
  }
}

class _DefaultSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DefaultSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: ColorsFrave.pillYellow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.addressUseAsDefault,
                  style: FraveText.medium(14, color: ColorsFrave.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.addressUseAsDefaultHint,
                  style: FraveText.regular(12, color: ColorsFrave.greyText),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: ColorsFrave.navOrange,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hintText,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
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