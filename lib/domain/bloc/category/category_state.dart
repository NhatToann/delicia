part of 'category_bloc.dart';

@immutable
class CategoryState {
  /// True while the list is loading.
  final bool isLoading;

  /// True while a create / update / delete is running.
  final bool isSubmitting;

  /// The last failure, if any.
  final AppFailure? error;

  /// Every category the platform holds.
  final List<Category> categories;

  /// The categories matching the current [query].
  final List<Category> visibleCategories;

  /// The current search text.
  final String query;

  /// Bumped to `true` after a successful create / update / delete so
  /// the screen can pop the form or show a confirmation.
  ///
  /// The flag is cleared by the next state that carries
  /// `clearActionSucceeded: true`.
  final bool actionSucceeded;

  const CategoryState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.categories = const <Category>[],
    this.visibleCategories = const <Category>[],
    this.query = '',
    this.actionSucceeded = false,
  });

  CategoryState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    AppFailure? error,
    bool clearError = false,
    List<Category>? categories,
    List<Category>? visibleCategories,
    String? query,
    bool? actionSucceeded,
    bool clearActionSucceeded = false,
  }) {
    return CategoryState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      categories: categories ?? this.categories,
      visibleCategories: visibleCategories ?? this.visibleCategories,
      query: query ?? this.query,
      actionSucceeded: clearActionSucceeded
          ? false
          : (actionSucceeded ?? this.actionSucceeded),
    );
  }
}
