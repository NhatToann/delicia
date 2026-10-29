/// Category model (UC-02).
///
/// Stored under `/delicia/categories/{id}` in the Realtime Database.
/// `picture` is a relative asset path (e.g. `categories/burgers.jpg`)
/// that is resolved by [ImageResolver] into a local `Image.asset`.
///
/// The optional [icon] (FontAwesome icon name) and [color] (ARGB int)
/// fields let the UI render a styled fallback when no real picture is
/// shipped with the app — keeps the catalog visually rich even before
/// assets are uploaded.
class Category {
  final String id;
  final String category;
  final String description;
  final String picture;
  final String icon;
  final int color;

  const Category({
    required this.id,
    required this.category,
    this.description = '',
    this.picture = '',
    this.icon = 'utensils',
    this.color = 0xFF5469D4,
  });

  factory Category.fromMap(String id, Map<dynamic, dynamic> map) {
    return Category(
      id: id,
      category: (map['category'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      picture: (map['picture'] ?? '').toString(),
      icon: (map['icon'] ?? 'utensils').toString(),
      color: _parseColor(map['color']),
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category,
        'description': description,
        'picture': picture,
        'icon': icon,
        'color': color,
      };

  Category copyWith({
    String? id,
    String? category,
    String? description,
    String? picture,
    String? icon,
    int? color,
  }) =>
      Category(
        id: id ?? this.id,
        category: category ?? this.category,
        description: description ?? this.description,
        picture: picture ?? this.picture,
        icon: icon ?? this.icon,
        color: color ?? this.color,
      );

  /// Empty placeholder used as the initial value for [ProductsState].
  static const Category empty = Category(id: '', category: '');

  static int _parseColor(dynamic raw) {
    if (raw == null) return 0xFF5469D4;
    if (raw is int) return raw;
    final str = raw.toString().replaceAll('0x', '').replaceAll('#', '');
    return int.tryParse(str, radix: 16) ?? 0xFF5469D4;
  }
}
