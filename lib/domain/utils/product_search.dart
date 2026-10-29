import '../models/product.dart';
import 'search_matcher.dart';

/// A product that matched the query, together with *why* it matched.
///
/// The score drives the ordering; the [matchedTokens] drive the
/// "why did this show up?" hint under the title.
class ProductSearchHit {
  final Productsdb product;

  /// Higher is better. See [ProductSearch] for the breakdown.
  final double score;

  /// The query tokens that this product matched, normalised.
  final List<String> matchedTokens;

  const ProductSearchHit({
    required this.product,
    required this.score,
    this.matchedTokens = const [],
  });
}

/// The catalogue search engine.
///
/// ## Why this lives in the domain layer
///
/// Search is pure text processing over rows we already hold in memory, so it
/// needs neither the network nor Flutter. Keeping it here means the ranking
/// rules can be unit-tested without pumping a widget, and both the bloc and
/// the presentation layer can use the exact same rules.
///
/// ## Why it is client-side
///
/// The Realtime Database has no full-text index and no combined
/// `name + description + categoryId` query. The old implementation called
/// `searchProducts()` on every keystroke, which meant one network round-trip
/// per character typed. The catalogue is small (tens of rows), so we fetch it
/// once and filter locally instead.
///
/// ## Matching rules
///
/// A product matches when **every** token in the query appears in at least
/// one of its searchable fields:
///
///   * [Productsdb.nameProduct]  — the Vietnamese name;
///   * [Productsdb.nameProductEn] — the original English name;
///   * [Productsdb.category]     — the Vietnamese category name;
///   * [Productsdb.description]  — the Vietnamese description.
///
/// The token-based rule ("all words must match") is what customers expect
/// from a search box: typing "truffle burger" should not return every
/// truffle *and* every burger.
///
/// Matching is accent-insensitive, so "bun bo" finds "Bún Bò".
class ProductSearch {
  const ProductSearch._();

  /// Filters [source] by [query] and orders the survivors by relevance.
  ///
  /// An empty or whitespace-only query returns every row in [source], in the
  /// order given — that is the "show everything first, filter as the user
  /// types" behaviour.
  ///
  /// Sold-out rows (`status != 1`) are dropped: the home screen already
  /// hides them, and their card still carries an "add to cart" button, so
  /// showing them in the results would let a customer order something the
  /// restaurant cannot serve.
  static List<Productsdb> filter(
    List<Productsdb> source,
    String query, {
    String? categoryId,
  }) {
    return rank(source, query, categoryId: categoryId)
        .map((hit) => hit.product)
        .toList();
  }

  /// Whether [product] matches [query].
  ///
  /// Same rules as [filter], but for a single row.
  static bool matches(Productsdb product, String query) {
    final tokens = searchTokens(query);
    if (tokens.isEmpty) return true;
    return fieldsMatch(_fields(product), tokens);
  }

  /// Filters [source] by [query], returning the hits with their scores.
  ///
  /// Pass [categoryId] to restrict the result to one category. The filter is
  /// applied *before* scoring, so the ranking is relative to what the
  /// customer can actually see.
  static List<ProductSearchHit> rank(
    List<Productsdb> source,
    String query, {
    String? categoryId,
  }) {
    final pool = source
        .where((p) => p.isActive)
        .where((p) => categoryId == null || categoryId.isEmpty || p.categoryId == categoryId)
        .toList();

    final tokens = searchTokens(query);
    if (tokens.isEmpty) {
      return pool
          .map((p) => ProductSearchHit(product: p, score: 0))
          .toList();
    }

    final hits = <ProductSearchHit>[];
    for (final product in pool) {
      final hit = _score(product, tokens);
      if (hit != null) hits.add(hit);
    }

    // Highest score first. Ties keep the catalogue order (stable sort), so
    // two equally good matches do not shuffle between keystrokes.
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits;
  }

  /// Scores one product against the query tokens, or returns `null` when the
  /// product does not match every token.
  static ProductSearchHit? _score(Productsdb product, List<String> tokens) {
    final fields = _fields(product);

    var score = 0.0;
    final matched = <String>[];

    for (final token in tokens) {
      final bestFieldScore = _bestFieldScore(fields, token);
      // Every token has to land somewhere, otherwise "truffle burger" would
      // match every burger and every truffle.
      if (bestFieldScore <= 0) return null;
      score += bestFieldScore;
      matched.add(token);
    }

    // Prefer shorter names when the score is otherwise equal: a query for
    // "burger" should show "Burger Nấm Truffle" above "Combo Burger Đặc Biệt
    // 2 Người Ăn Kèm Khoai Tây".
    score += _lengthBonus(product.nameProduct);

    return ProductSearchHit(
      product: product,
      score: score,
      matchedTokens: matched,
    );
  }

  /// The normalised searchable fields of one product.
  static SearchFields _fields(Productsdb product) {
    return SearchFields.normalised(
      name: product.nameProduct,
      nameEn: product.nameProductEn,
      category: product.category,
      description: product.description,
    );
  }

  /// The best score a token can earn across the searchable fields.
  ///
  /// A hit in the name is worth more than a hit in the description, and an
  /// early hit is worth more than a late one.
  static double _bestFieldScore(SearchFields fields, String token) {
    final candidates = <double>[
      _fieldScore(fields.name, token, SearchField.name.weight),
      _fieldScore(fields.nameEn, token, SearchField.nameEn.weight),
      _fieldScore(fields.category, token, SearchField.category.weight),
      _fieldScore(fields.description, token, SearchField.description.weight),
    ];
    var best = 0.0;
    for (final candidate in candidates) {
      if (candidate > best) best = candidate;
    }
    return best;
  }

  static double _fieldScore(String text, String token, double weight) {
    if (text.isEmpty) return 0;
    final strength = matchStrength(text, token);
    if (strength <= 0) return 0;
    return weight * strength;
  }

  /// Small bonus for shorter product names, to break score ties.
  static double _lengthBonus(String name) {
    final length = name.trim().length;
    if (length <= 0) return 0;
    return (1 / length) * 0.5;
  }
}

/// The searchable fields of a product, with their scoring weights.
enum SearchField {
  /// The Vietnamese display name — the most important field.
  name(3.0),

  /// The original English name, kept so English queries still work.
  nameEn(2.5),

  /// The Vietnamese category name ("Bánh Burger", "Đồ Uống").
  category(1.5),

  /// The Vietnamese description — the weakest signal.
  description(1.0);

  const SearchField(this.weight);

  /// Multiplier applied to a match in this field.
  final double weight;
}
