import '../utils/search_matcher.dart';
import 'product_option.dart';

/// Product model (UC-02).
///
/// Stored under `/delicia/products/{id}` in the Realtime Database.
/// The `status` field mirrors the original Frave backend: `1` = active,
/// `0` = sold out / inactive.
///
/// The home screen needs a few presentation-grade fields that the original
/// schema never had. They are optional so existing rows keep parsing:
///
///   * [rating]      — average star rating (0..5) shown on home cards.
///   * [ratingCount]  — number of reviews behind [rating].
///   * [sold]        — units sold, used by "Best Seller" ordering.
///   * [isRecommended] / [isBestSeller] — home rail membership flags.
class Productsdb {
  final String id;
  final String nameProduct;
  final String description;
  final double price;
  final int status;
  final String picture;
  final String category;
  final String categoryId;
  final double rating;
  final int ratingCount;
  final int sold;
  final bool isRecommended;
  final bool isBestSeller;
  final String restaurantName;

  /// The original English dish name, kept so the search field can still
  /// match "burger" / "pizza" while the catalogue itself is Vietnamese.
  final String nameProductEn;

  /// The "was" price shown struck through next to [price]. Kept as a
  /// number (not a formatted string) so it can be rendered with the same
  /// currency formatter as [price].
  final double? oldPrice;

  /// The selectable sizes / portions of this product.
  ///
  /// Stored under `/delicia/products/{id}/options`. Empty when the row has
  /// no options yet — the detail screen then falls back to a single
  /// implicit "base" variant priced at [price].
  final List<ProductOption> options;

  const Productsdb({
    required this.id,
    required this.nameProduct,
    required this.description,
    required this.price,
    required this.status,
    required this.picture,
    required this.category,
    required this.categoryId,
    this.rating = 0,
    this.ratingCount = 0,
    this.sold = 0,
    this.isRecommended = false,
    this.isBestSeller = false,
    this.restaurantName = '',
    this.nameProductEn = '',
    this.oldPrice,
    this.options = const <ProductOption>[],
  });

  factory Productsdb.fromMap(String id, Map<dynamic, dynamic> map) {
    return Productsdb(
      id: id,
      nameProduct: (map['nameProduct'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      price: _parseDouble(map['price']),
      status: int.tryParse((map['status'] ?? '1').toString()) ?? 1,
      picture: (map['picture'] ?? '').toString(),
      category: (map['category'] ?? '').toString(),
      categoryId: (map['categoryId'] ?? '').toString(),
      rating: _parseDouble(map['rating']),
      ratingCount: _parseInt(map['ratingCount']),
      sold: _parseInt(map['sold']),
      isRecommended: _parseBool(map['isRecommended']),
      isBestSeller: _parseBool(map['isBestSeller']),
      restaurantName: (map['restaurantName'] ?? '').toString(),
      nameProductEn: (map['nameProductEn'] ?? '').toString(),
      oldPrice: map['oldPrice'] == null
          ? null
          : _parseDouble(map['oldPrice']),
      options: _parseOptions(map['options']),
    );
  }

  Map<String, dynamic> toMap() => {
        'nameProduct': nameProduct,
        'description': description,
        'price': price,
        'status': status,
        'picture': picture,
        'category': category,
        'categoryId': categoryId,
        'rating': rating,
        'ratingCount': ratingCount,
        'sold': sold,
        'isRecommended': isRecommended,
        'isBestSeller': isBestSeller,
        'restaurantName': restaurantName,
        'nameProductEn': nameProductEn,
        if (oldPrice != null) 'oldPrice': oldPrice,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toMap()).toList(),
      };

  bool get isActive => status == 1;

  /// Whether the row carries a usable price.
  ///
  /// A row can parse perfectly well and still carry no price at all —
  /// that is exactly what happened to the live catalogue in October 2026,
  /// when a `PATCH` wiped every field except the translated ones. The
  /// price then fell back to `0.0` and the whole app showed "0 ₫".
  ///
  /// This flag lets the UI tell "this dish is free" apart from "this row
  /// is broken", so the broken case can be surfaced instead of silently
  /// rendering a zero.
  bool get hasPrice => price > 0;

  /// True when the row carries enough signal to render a star badge.
  bool get hasRating => rating > 0;

  /// The discount of this product, as a whole percentage, or null when the
  /// dish is not on offer.
  ///
  /// Figma node `192:1216` draws a starburst badge in the corner of the
  /// photo reading "-30%". The badge's *number* is derived from the row's
  /// own `oldPrice` and `price` — it is never a hardcoded constant, so a
  /// product without a "was" price simply shows no badge.
  ///
  /// The percentage is rounded to the nearest whole percent, and the badge
  /// is only shown from [minDiscountPercent] upwards so a rounding artefact
  /// (e.g. 0.4 %) never surfaces as a "-0%" badge.
  int? get discountPercent {
    final was = oldPrice;
    if (was == null || was <= 0 || price <= 0) return null;
    if (was <= price) return null;
    final percent = ((was - price) / was * 100).round();
    if (percent < minDiscountPercent) return null;
    return percent;
  }

  /// The smallest discount that is worth showing as a badge.
  static const int minDiscountPercent = 1;

  /// Whether this product matches a free-text search query.
  ///
  /// The catalogue copy is Vietnamese, but every row keeps its original
  /// English name in [nameProductEn] — so a customer who types "burger"
  /// still finds "Burger Nấm Truffle Đặc Trưng". The comparison is
  /// case-insensitive and accent-insensitive on the Vietnamese side, so
  /// "BURGER" and "bánh burger" behave the same.
  ///
  /// Every token in the query has to match (an "AND" search), and the
  /// rules live in `search_matcher.dart` so this method and the
  /// `ProductSearch` ranking engine cannot drift apart.
  bool matchesQuery(String query) {
    final tokens = searchTokens(query);
    if (tokens.isEmpty) return true;
    return fieldsMatch(
      SearchFields.normalised(
        name: nameProduct,
        nameEn: nameProductEn,
        category: category,
        description: description,
      ),
      tokens,
    );
  }

  Productsdb copyWith({
    String? id,
    String? nameProduct,
    String? description,
    double? price,
    int? status,
    String? picture,
    String? category,
    String? categoryId,
    double? rating,
    int? ratingCount,
    int? sold,
    bool? isRecommended,
    bool? isBestSeller,
    String? restaurantName,
    String? nameProductEn,
    double? oldPrice,
    List<ProductOption>? options,
  }) =>
      Productsdb(
        id: id ?? this.id,
        nameProduct: nameProduct ?? this.nameProduct,
        description: description ?? this.description,
        price: price ?? this.price,
        status: status ?? this.status,
        picture: picture ?? this.picture,
        category: category ?? this.category,
        categoryId: categoryId ?? this.categoryId,
        rating: rating ?? this.rating,
        ratingCount: ratingCount ?? this.ratingCount,
        sold: sold ?? this.sold,
        isRecommended: isRecommended ?? this.isRecommended,
        isBestSeller: isBestSeller ?? this.isBestSeller,
        restaurantName: restaurantName ?? this.restaurantName,
        nameProductEn: nameProductEn ?? this.nameProductEn,
        oldPrice: oldPrice ?? this.oldPrice,
        options: options ?? this.options,
      );

  static double _parseDouble(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  static int _parseInt(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }

  /// Firebase stores booleans as `true`/`false`, but hand-written seed data
  /// sometimes writes `1`/`0` or `"true"`. Accept all three.
  static bool _parseBool(dynamic raw) {
    if (raw == null) return false;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final s = raw.toString().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  /// Parses the `options` array.
  ///
  /// Firebase hands back a `List<dynamic>` of `Map<String, dynamic>`, but a
  /// hand-written seed can also store the options as a keyed map
  /// (`opt1: {...}`). Both shapes are accepted so a malformed row can
  /// never crash the catalogue.
  static List<ProductOption> _parseOptions(dynamic raw) {
    if (raw is! List) {
      if (raw is Map) {
        return raw.entries
            .map((e) => ProductOption.fromMap(
                  e.key.toString(),
                  Map<dynamic, dynamic>.from(e.value as Map),
                ))
            .toList();
      }
      return const <ProductOption>[];
    }
    final result = <ProductOption>[];
    for (final entry in raw) {
      if (entry is Map) {
        result.add(
          ProductOption.fromMap(
            (entry['id'] ?? '').toString(),
            Map<dynamic, dynamic>.from(entry),
          ),
        );
      }
    }
    return result;
  }
}