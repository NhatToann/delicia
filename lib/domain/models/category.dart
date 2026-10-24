/// Category model (UC-02).
///
/// Stored under `/delicia/categories/{id}` in the Realtime Database.
/// `picture` is a relative asset path (e.g. `categories/burgers.jpg`)
/// that is resolved by [ImageResolver] into a local `Image.asset`.
class Category {
  final String id;
  final String category;
  final String description;
  final String picture;

  const Category({
    required this.id,
    required this.category,
    this.description = '',
    this.picture = '',
  });

  factory Category.fromMap(String id, Map<dynamic, dynamic> map) {
    return Category(
      id: id,
      category: (map['category'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      picture: (map['picture'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category,
        'description': description,
        'picture': picture,
      };

  Category copyWith({
    String? id,
    String? category,
    String? description,
    String? picture,
  }) =>
      Category(
        id: id ?? this.id,
        category: category ?? this.category,
        description: description ?? this.description,
        picture: picture ?? this.picture,
      );

  /// Empty placeholder used as the initial value for [ProductsState].
  static const Category empty = Category(id: '', category: '');
}