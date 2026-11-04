part of 'category_bloc.dart';

@immutable
abstract class CategoryEvent {
  const CategoryEvent();
}

/// Loads the category list.
class CategoryLoadRequested extends CategoryEvent {
  const CategoryLoadRequested();
}

/// Filters the visible list by name. Pure UI state — no network call.
class CategorySearchChanged extends CategoryEvent {
  const CategorySearchChanged(this.query);
  final String query;
}

/// Creates a category.
///
/// [imageBytes] / [imageContentType] carry the freshly picked photo. When
/// they are present the bloc uploads the picture to Storage first and
/// stores the resulting download URL in the row — the presentation layer
/// never talks to Firebase itself.
class CategoryCreateRequested extends CategoryEvent {
  const CategoryCreateRequested({
    required this.category,
    this.imageBytes,
    this.imageContentType,
  });

  final Category category;
  final Uint8List? imageBytes;
  final String? imageContentType;
}

/// Updates an existing category.
class CategoryUpdateRequested extends CategoryEvent {
  const CategoryUpdateRequested({
    required this.category,
    this.imageBytes,
    this.imageContentType,
  });

  final Category category;
  final Uint8List? imageBytes;
  final String? imageContentType;
}

/// Deletes a category (and its products).
class CategoryDeleteRequested extends CategoryEvent {
  const CategoryDeleteRequested(this.id);
  final String id;
}
