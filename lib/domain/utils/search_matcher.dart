import 'text_normalizer.dart';

/// The searchable fields of a product, already normalised.
///
/// This is a leaf module: it knows nothing about the product model and
/// nothing about Flutter. Both the product model's `matchesQuery` and the
/// `ProductSearch` ranking engine build a [SearchFields] from a row and
/// share the rules below, so the two can never drift apart.
class SearchFields {
  /// The Vietnamese display name.
  final String name;

  /// The original English name (empty when the row has none).
  final String nameEn;

  /// The Vietnamese category name.
  final String category;

  /// The Vietnamese description.
  final String description;

  const SearchFields({
    required this.name,
    this.nameEn = '',
    this.category = '',
    this.description = '',
  });

  /// Normalises the raw field values (lower-case, no diacritics).
  factory SearchFields.normalised({
    required String name,
    String nameEn = '',
    String category = '',
    String description = '',
  }) {
    return SearchFields(
      name: stripDiacritics(name.toLowerCase()),
      nameEn: stripDiacritics(nameEn.toLowerCase()),
      category: stripDiacritics(category.toLowerCase()),
      description: stripDiacritics(description.toLowerCase()),
    );
  }

  /// The fields in descending order of importance.
  ///
  /// The order matters for scoring: a hit in the name is worth more than a
  /// hit in the description.
  List<String> get byImportance => <String>[name, nameEn, category, description];
}

/// Splits a raw query into normalised tokens.
///
/// Whitespace separates tokens; commas, slashes and the like are treated as
/// separators too, so a pasted "pizza, burger" behaves like two words.
List<String> searchTokens(String query) {
  return collapseWhitespace(
        query.toLowerCase().replaceAll(RegExp(r'[,\/;|]+'), ' '),
      )
      .split(' ')
      .where((t) => t.isNotEmpty)
      .map(stripDiacritics)
      .where((t) => t.isNotEmpty)
      .toList();
}

/// Whether every token in [tokens] appears in at least one of [fields].
///
/// This is the "AND" rule a customer expects from a search box: typing
/// "truffle burger" must not return every truffle *and* every burger.
bool fieldsMatch(SearchFields fields, List<String> tokens) {
  if (tokens.isEmpty) return true;
  final haystack = fields.byImportance;
  for (final token in tokens) {
    var found = false;
    for (final field in haystack) {
      if (field.contains(token)) {
        found = true;
        break;
      }
    }
    if (!found) return false;
  }
  return true;
}

/// Whether [text] contains [token], and how strongly.
///
/// The score decays with the distance from the start of the text: "burger"
/// at position 0 of "burger pho mai" is a stronger signal than the same
/// word buried at position 30 of a long description.
double matchStrength(String text, String token) {
  final index = text.indexOf(token);
  if (index < 0) return 0;
  if (index == 0) return 1;
  // Decay from 1.0 down to ~0.4 over the first 90 characters.
  return 1 - (index / 150).clamp(0, 0.6);
}
