import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/address/address_bloc.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/models/client_address.dart';
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

  String? _selectedCity;
  String? _selectedDistrict;
  String? _selectedWard;

  final List<String> _cities = ['Đà Nẵng', 'Hồ Chí Minh', 'Hà Nội'];

  final Map<String, List<String>> _districts = {
    'Đà Nẵng': [
      'Hải Châu',
      'Thanh Khê',
      'Sơn Trà',
      'Ngũ Hành Sơn',
      'Liên Chiểu',
      'Cẩm Lệ',
      'Hòa Vang',
    ],
    'Hồ Chí Minh': [
      'Quận 1',
      'Quận 3',
      'Quận 4',
      'Quận 5',
      'Quận 7',
      'Quận 10',
      'Phú Nhuận',
      'Bình Thạnh',
      'Tân Bình',
      'Thủ Đức',
    ],
    'Hà Nội': [
      'Ba Đình',
      'Hoàn Kiếm',
      'Đống Đa',
      'Cầu Giấy',
      'Thanh Xuân',
      'Hai Bà Trưng',
      'Tây Hồ',
      'Long Biên',
    ],
  };

  final Map<String, List<String>> _wards = {
    'Hải Châu': ['Thạch Thang', 'Hải Châu 1', 'Hải Châu 2', 'Nam Dương', 'Phước Ninh', 'Bình Thuận', 'Bình Hiên', 'Hòa Thuận Đông', 'Hòa Thuận Tây', 'Thuận Phước', 'Hòa Cường Bắc', 'Hòa Cường Nam'],
    'Thanh Khê': ['Vĩnh Trung', 'Thạc Gián', 'Chính Gián', 'Tân Chính', 'An Khê', 'Hòa Khê', 'Thanh Khê Đông', 'Thanh Khê Tây', 'Xuân Hà', 'Tam Thuận'],
    'Sơn Trà': ['Thọ Quang', 'Nại Hiên Đông', 'Mân Thái', 'An Hải Bắc', 'An Hải Tây', 'An Hải Đông', 'Phước Mỹ'],
    'Ngũ Hành Sơn': ['Mỹ An', 'Khuê Mỹ', 'Hòa Hải', 'Hòa Quý'],
    'Liên Chiểu': ['Hòa Minh', 'Hòa Khánh Nam', 'Hòa Khánh Bắc', 'Hòa Hiệp Nam', 'Hòa Hiệp Bắc'],
    'Cẩm Lệ': ['Khuê Trung', 'Hòa An', 'Hòa Phát', 'Hòa Thọ Đông', 'Hòa Thọ Tây', 'Hòa Xuân'],
    'Hòa Vang': ['Hòa Bắc', 'Hòa Liên', 'Hòa Nhơn', 'Hòa Ninh', 'Hòa Phong', 'Hòa Phú', 'Hòa Phước', 'Hòa Sơn', 'Hòa Tiến'],
    'Quận 1': ['Bến Nghé', 'Bến Thành', 'Cầu Kho', 'Cầu Ông Lãnh', 'Cô Giang', 'Đa Kao', 'Nguyễn Cư Trinh', 'Nguyễn Thái Bình', 'Phạm Ngũ Lão', 'Tân Định'],
    'Quận 3': ['Phường 01', 'Phường 02', 'Phường 03', 'Phường 04', 'Phường 05', 'Phường 09', 'Phường 10', 'Phường 11', 'Phường 12', 'Phường 13', 'Phường 14', 'Võ Thị Sáu'],
    'Quận 7': ['Bình Thuận', 'Phú Mỹ', 'Phú Thuận', 'Tân Hưng', 'Tân Kiểng', 'Tân Phong', 'Tân Phú', 'Tân Quy', 'Tân Thuận Đông', 'Tân Thuận Tây'],
    'Thủ Đức': ['Bình Chiểu', 'Bình Thọ', 'Hiệp Bình Chánh', 'Hiệp Bình Phước', 'Linh Chiểu', 'Linh Đông', 'Linh Tây', 'Linh Trung', 'Tam Bình', 'Tam Phú', 'Tường Thọ'],
    'Ba Đình': ['Cống Vị', 'Điện Biên', 'Đội Cấn', 'Giảng Võ', 'Kim Mã', 'Liễu Giai', 'Ngọc Hà', 'Ngọc Khánh', 'Phúc Xá', 'Quán Thánh', 'Thành Công', 'Trúc Bạch'],
    'Hoàn Kiếm': ['Cửa Đông', 'Cửa Nam', 'Đồng Xuân', 'Hàng Bạc', 'Hàng Bài', 'Hàng Bồ', 'Hàng Bông', 'Hàng Buồm', 'Hàng Đào', 'Hàng Gai', 'Hàng Mã', 'Hàng Trống', 'Lý Thái Tổ', 'Phan Chu Trinh', 'Tràng Tiền'],
    'Cầu Giấy': ['Dịch Vọng', 'Dịch Vọng Hậu', 'Mai Dịch', 'Nghĩa Đô', 'Nghĩa Tân', 'Quan Hoa', 'Trung Hòa', 'Yên Hòa'],
  };

  @override
  void initState() {
    super.initState();
    final a = widget.existingAddress;
    if (a != null && a.street.isNotEmpty) {
      // Chỉ lấy phần tên đường/số nhà đầu tiên trước dấu phẩy để tránh dồn rác phường/quận cũ
      final streetOnly = a.street.split(',').first.trim();
      _street = TextEditingController(text: streetOnly);
    } else {
      _street = TextEditingController(text: '');
    }

    _reference = TextEditingController(text: a?.reference ?? '');
    _isDefault = a?.isDefault ?? false;
    _editingId = a?.id ?? '';

    _selectedCity = _cities.first;
    _selectedDistrict = _districts[_selectedCity]?.first;
    _selectedWard = _wards[_selectedDistrict]?.first ?? 'Phường/Xã';
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
                                  items: _cities,
                                  selectedItem: _selectedCity,
                                  onSelected: (val) {
                                    setState(() {
                                      _selectedCity = val;
                                      final districtsList = _districts[val];
                                      _selectedDistrict = (districtsList != null && districtsList.isNotEmpty)
                                          ? districtsList.first
                                          : null;
                                      final wardsList = _selectedDistrict != null ? _wards[_selectedDistrict] : null;
                                      _selectedWard = (wardsList != null && wardsList.isNotEmpty)
                                          ? wardsList.first
                                          : 'Chọn Phường/Xã';
                                    });
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildSelectorField(
                              label: 'Quận / Huyện',
                              value: _selectedDistrict ?? 'Chọn Quận/Huyện',
                              onTap: () {
                                final List<String> districts = _selectedCity != null
                                    ? (_districts[_selectedCity] ?? <String>[])
                                    : <String>[];
                                _openSelectorModal(
                                  title: 'Chọn Quận / Huyện',
                                  items: districts,
                                  selectedItem: _selectedDistrict,
                                  onSelected: (val) {
                                    setState(() {
                                      _selectedDistrict = val;
                                      final List<String>? wardsList = _wards[val];
                                      _selectedWard = (wardsList != null && wardsList.isNotEmpty)
                                          ? wardsList.first
                                          : 'Không có phường/xã';
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
                                final List<String> wards = _selectedDistrict != null
                                    ? (_wards[_selectedDistrict] ?? <String>['Chọn Phường/Xã'])
                                    : <String>['Chọn Phường/Xã'];
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
        '${_selectedDistrict ?? ""}, '
        '${_selectedCity ?? ""}';

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
            latitude: 0.0,
            longitude: 0.0,
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
            latitude: 0.0,
            longitude: 0.0,
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