import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/bloc/product/product_bloc.dart';
import '../../../domain/models/category.dart';
import '../../../domain/models/product.dart';
import '../../../domain/services/admin_catalog_service.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../components/btn_frave.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import 'widgets/image_picker_widget.dart';

/// AdminProductFormScreen — create / edit a product (UC-08).
///
/// The form covers the whole product row: name, description, price,
/// category and the photo. The category is picked from a dropdown — the
/// id is what the row stores, never the display name.
///
/// The price is edited in **VND**, the same unit the database stores it
/// in and the same unit the customer reads on the card. Admin and
/// customer therefore always agree on what a dish costs.
class AdminProductFormScreen extends StatelessWidget {
  const AdminProductFormScreen({
    super.key,
    this.product,
    this.productId = '',
  });

  /// The product to edit — `null` creates a new one.
  final Productsdb? product;

  /// The id of the product to edit. When [product] is `null` the screen
  /// looks the row up in the catalogue the bloc loads.
  final String productId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProductBloc>(
      create: (context) => ProductBloc(
        catalogService: context.read<AdminCatalogService>(),
        imageUploadService: context.read<ImageUploadService>(),
      )..add(const ProductLoadRequested()),
      child: _AdminProductFormView(
        product: product,
        productId: productId,
      ),
    );
  }
}

class _AdminProductFormView extends StatefulWidget {
  const _AdminProductFormView({this.product, this.productId = ''});

  final Productsdb? product;
  final String productId;

  @override
  State<_AdminProductFormView> createState() => _AdminProductFormViewState();
}

class _AdminProductFormViewState extends State<_AdminProductFormView> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;

  /// Focus of the price field — used to regroup the number with the
  /// Vietnamese thousands separator once the admin leaves the field.
  late final FocusNode _priceFocus;

  /// The category the product belongs to.
  String _categoryId = '';

  /// The bytes of the freshly picked photo.
  Uint8List? _pendingBytes;
  String _pendingContentType = 'image/jpeg';

  /// The URL of the photo that is already stored.
  String _pictureUrl = '';

  /// Whether the product is in stock.
  bool _isActive = true;

  /// The product being edited — resolved once the catalogue arrives.
  Productsdb? _entity;

  /// Guards the one-shot hydration of the form fields.
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.nameProduct ?? '');
    _descriptionController =
        TextEditingController(text: product?.description ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : _formatPrice(product.price),
    );
    _priceFocus = FocusNode()..addListener(_regroupPrice);
    _categoryId = product?.categoryId ?? '';
    _pictureUrl = product?.picture ?? '';
    _isActive = product?.isActive ?? true;
    _entity = product;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.product != null || widget.productId.isNotEmpty;

  /// Fills the form with the row the catalogue holds.
  void _hydrate(Productsdb product) {
    if (_hydrated) return;
    _hydrated = true;
    _entity = product;
    _nameController.text = product.nameProduct;
    _descriptionController.text = product.description;
    _priceController.text = _formatPrice(product.price);
    _categoryId = product.categoryId;
    _pictureUrl = product.picture;
    _isActive = product.isActive;
  }

  /// The price field is edited in **VND** — the same number the customer
  /// sees on the card (`180.000`), and the same number the database
  /// stores (`180000`).
  ///
  /// Admin and customer therefore always agree on what a dish costs, and
  /// the value written back is the number that was typed — no conversion.
  static String _formatPrice(double vnd) {
    if (vnd == 0) return '';
    return Money.formatVndPlain(vnd);
  }

  /// Rewrites the price with the Vietnamese thousands separator once the
  /// admin leaves the field, so `180000` reads as `180.000`.
  ///
  /// While the field has focus the raw digits are left alone — inserting
  /// a separator mid-typing would move the caret around and fight the
  /// keyboard.
  void _regroupPrice() {
    if (_priceFocus.hasFocus) return;
    final vnd = Money.parseVnd(_priceController.text);
    if (vnd == null) return;
    final regrouped = Money.formatVndPlain(vnd);
    if (regrouped == _priceController.text) return;
    final selection = _priceController.selection;
    final offset = selection.baseOffset.clamp(0, regrouped.length);
    _priceController.value = TextEditingValue(
      text: regrouped,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = context.select<ProductBloc, List<Category>>(
      (bloc) => bloc.state.categories,
    );

    // The row to edit may only be known after the catalogue loaded.
    if (_entity == null && widget.productId.isNotEmpty) {
      final match = context.select<ProductBloc, Productsdb?>(
        (bloc) {
          for (final product in bloc.state.products) {
            if (product.id == widget.productId) return product;
          }
          return null;
        },
      );
      if (match != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _hydrate(match));
        });
      }
    }

    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      appBar: AppBar(
        backgroundColor: ColorsFrave.navOrange,
        foregroundColor: ColorsFrave.onOrange,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(
          _isEditing ? l10n.adminProductEdit : l10n.adminProductAdd,
          style: FraveText.semiBold(20, color: ColorsFrave.onOrange),
        ),
      ),
      body: BlocListener<ProductBloc, ProductState>(
        listenWhen: (previous, current) =>
            previous.actionSucceeded != current.actionSucceeded ||
            previous.error != current.error,
        listener: (context, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
            return;
          }
          if (state.actionSucceeded) {
            successSnack(context, l10n.adminProductSaved);
            Navigator.of(context).pop(true);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: <Widget>[
            AdminImagePicker(
              label: l10n.adminProductImage,
              existingUrl: _pictureUrl,
              onPicked: (bytes, contentType) {
                setState(() {
                  _pendingBytes = bytes;
                  _pendingContentType = contentType;
                });
              },
            ),
            const SizedBox(height: 20),
            _Field(
              label: l10n.adminProductName,
              controller: _nameController,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _Field(
              label: l10n.adminProductDescription,
              controller: _descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _PriceField(
              label: l10n.adminProductPrice,
              controller: _priceController,
              focusNode: _priceFocus,
            ),
            const SizedBox(height: 14),
            _CategoryDropdown(
              categories: categories,
              selectedId: _categoryId,
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.adminProductInStock,
                style: FraveText.medium(14, color: ColorsFrave.ink),
              ),
              activeThumbColor: ColorsFrave.navOrange,
            ),
            const SizedBox(height: 20),
            BtnFrave(
              text: _isEditing ? l10n.actionSave : l10n.adminProductAdd,
              isLoading: context.select<ProductBloc, bool>(
                (bloc) => bloc.state.isSubmitting,
              ),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      errorTextSnack(context, l10n.adminProductNameRequired);
      return;
    }

    // The field is typed in VND — `180.000` means 180 000 ₫. The dots are
    // the Vietnamese thousands separator, so they are stripped before the
    // digits are read, and the amount is stored as it is: the database
    // holds VND, so no conversion happens here.
    final vnd = Money.parseVnd(_priceController.text.trim());
    if (vnd == null || vnd < 0) {
      errorTextSnack(context, l10n.adminProductPriceRequired);
      return;
    }

    if (_categoryId.isEmpty) {
      errorTextSnack(context, l10n.adminProductCategoryRequired);
      return;
    }

    final categories = context.read<ProductBloc>().state.categories;
    final categoryName = categories
        .where((c) => c.id == _categoryId)
        .map((c) => c.category)
        .firstOrNull ??
        '';

    final existing = _entity;

    final product = (existing ?? Productsdb.empty).copyWith(
      nameProduct: name,
      description: _descriptionController.text.trim(),
      price: vnd.toDouble(),
      categoryId: _categoryId,
      category: categoryName,
      status: _isActive ? 1 : 0,
    );

    context.read<ProductBloc>().add(
          _isEditing
              ? ProductUpdateRequested(
                  product: product,
                  imageBytes: _pendingBytes,
                  imageContentType: _pendingContentType,
                )
              : ProductCreateRequested(
                  product: product,
                  imageBytes: _pendingBytes,
                  imageContentType: _pendingContentType,
                ),
        );
  }
}

/// The price field of the admin product form.
///
/// It is a dedicated widget rather than a plain [_Field] because a price
/// needs its own keyboard contract:
///
///   * the **numeric keypad** is requested, so the admin never has to
///     hunt for the digits on a full keyboard;
///   * only digits are accepted — the field can never hold a letter, a
///     sign or a decimal separator, which is what used to make typing
///     feel broken;
///   * the thousands separator is added by the parent once the field
///     loses focus, so the digits are never disturbed mid-typing.
class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.controller,
    required this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: FraveText.medium(14, color: ColorsFrave.ink),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          // Digits only. A dot would be read as a decimal separator and
          // a letter would make the whole amount unparseable.
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: FraveText.regular(14, color: ColorsFrave.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: ColorsFrave.surfaceColor,
            suffixText: Money.symbol,
            suffixStyle: FraveText.regular(13, color: ColorsFrave.greyText),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: const BorderSide(color: ColorsFrave.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: const BorderSide(color: ColorsFrave.navOrange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// The category dropdown of the product form.
class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  final List<Category> categories;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The dropdown must always carry the selected id, even when the
    // category list has not loaded yet — otherwise the selection would
    // silently jump to the first entry.
    final ids = <String>{
      for (final c in categories) c.id,
      if (selectedId.isNotEmpty) selectedId,
    }.toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.adminProductCategory,
          style: FraveText.medium(14, color: ColorsFrave.ink),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          initialValue: selectedId.isEmpty ? null : selectedId,
          isExpanded: true,
          hint: Text(
            l10n.adminProductCategory,
            style: FraveText.regular(14, color: ColorsFrave.greyText),
          ),
          style: FraveText.regular(14, color: ColorsFrave.ink),
          icon: const Icon(Icons.expand_more, color: ColorsFrave.greyText),
          items: <DropdownMenuItem<String>>[
            for (final id in ids)
              DropdownMenuItem<String>(
                value: id,
                child: Text(
                  categories
                      .where((c) => c.id == id)
                      .map((c) => c.category)
                      .firstOrNull ??
                    id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.regular(14, color: ColorsFrave.ink),
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: ColorsFrave.surfaceColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: const BorderSide(color: ColorsFrave.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: const BorderSide(color: ColorsFrave.navOrange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// A labelled text field of the admin forms.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: FraveText.medium(14, color: ColorsFrave.ink),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textInputAction: textInputAction,
          style: FraveText.regular(14, color: ColorsFrave.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: ColorsFrave.surfaceColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: const BorderSide(color: ColorsFrave.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: const BorderSide(color: ColorsFrave.navOrange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
