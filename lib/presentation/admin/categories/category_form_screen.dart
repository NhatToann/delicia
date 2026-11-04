import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/bloc/category/category_bloc.dart';
import '../../../domain/models/category.dart';
import '../../../domain/services/admin_catalog_service.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../components/btn_frave.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import '../products/widgets/image_picker_widget.dart';

/// AdminCategoryFormScreen — create / edit a category (UC-08).
///
/// The screen is used for both flows: without an id it creates a new
/// category, with an id it loads the existing row and edits it.
///
/// The picked photo is uploaded to Firebase Storage by the bloc, so the
/// screen only ever hands over bytes — it never talks to Firebase.
class AdminCategoryFormScreen extends StatelessWidget {
  const AdminCategoryFormScreen({
    super.key,
    this.category,
    this.categoryId = '',
  });

  /// The category to edit — `null` creates a new one.
  final Category? category;

  /// The id of the category to edit. When [category] is `null` the
  /// screen looks the row up in the catalogue the bloc loads.
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CategoryBloc>(
      create: (context) => CategoryBloc(
        catalogService: context.read<AdminCatalogService>(),
        imageUploadService: context.read<ImageUploadService>(),
      )..add(const CategoryLoadRequested()),
      child: _AdminCategoryFormView(
        category: category,
        categoryId: categoryId,
      ),
    );
  }
}

class _AdminCategoryFormView extends StatefulWidget {
  const _AdminCategoryFormView({this.category, this.categoryId = ''});

  final Category? category;
  final String categoryId;

  @override
  State<_AdminCategoryFormView> createState() => _AdminCategoryFormViewState();
}

class _AdminCategoryFormViewState extends State<_AdminCategoryFormView> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  /// The bytes of the freshly picked photo (uploaded on save).
  Uint8List? _pendingBytes;
  String _pendingContentType = 'image/jpeg';

  /// The URL of the photo that is already stored.
  String _pictureUrl = '';

  /// The category being edited — resolved once the catalogue arrives.
  Category? _entity;

  /// Guards the one-shot hydration of the form fields.
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.category ?? '');
    _descriptionController =
        TextEditingController(text: category?.description ?? '');
    _pictureUrl = category?.picture ?? '';
    _entity = category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.category != null || widget.categoryId.isNotEmpty;

  /// Fills the form with the row the catalogue holds.
  void _hydrate(Category category) {
    if (_hydrated) return;
    _hydrated = true;
    _entity = category;
    _nameController.text = category.category;
    _descriptionController.text = category.description;
    _pictureUrl = category.picture;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // The row to edit may only be known after the catalogue loaded.
    if (_entity == null && widget.categoryId.isNotEmpty) {
      final match = context.select<CategoryBloc, Category?>(
        (bloc) {
          for (final category in bloc.state.categories) {
            if (category.id == widget.categoryId) return category;
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
          _isEditing ? l10n.adminCategoryEdit : l10n.adminCategoryAdd,
          style: FraveText.semiBold(20, color: ColorsFrave.onOrange),
        ),
      ),
      body: BlocListener<CategoryBloc, CategoryState>(
        listenWhen: (previous, current) =>
            previous.actionSucceeded != current.actionSucceeded ||
            previous.error != current.error,
        listener: (context, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
            return;
          }
          if (state.actionSucceeded) {
            successSnack(context, l10n.adminCategorySaved);
            Navigator.of(context).pop(true);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: <Widget>[
            AdminImagePicker(
              label: l10n.adminCategoryImage,
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
              label: l10n.adminCategoryName,
              controller: _nameController,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            _Field(
              label: l10n.adminCategoryDescription,
              controller: _descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 28),
            BtnFrave(
              text: _isEditing ? l10n.actionSave : l10n.adminCategoryAdd,
              isLoading: context.select<CategoryBloc, bool>(
                (bloc) => bloc.state.isSubmitting,
              ),
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      errorTextSnack(context, l10n.adminCategoryNameRequired);
      return;
    }
    if (name.length > 60) {
      errorTextSnack(context, l10n.adminCategoryNameTooLong);
      return;
    }

    final bloc = context.read<CategoryBloc>();
    final existing = _entity;

    // The picture URL is only rewritten by the bloc, after the upload
    // succeeded — until then the old one stays in place.
    final category = (existing ?? Category.empty).copyWith(
      category: name,
      description: _descriptionController.text.trim(),
    );

    bloc.add(
      _isEditing
          ? CategoryUpdateRequested(
              category: category,
              imageBytes: _pendingBytes,
              imageContentType: _pendingContentType,
            )
          : CategoryCreateRequested(
              category: category,
              imageBytes: _pendingBytes,
              imageContentType: _pendingContentType,
            ),
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
