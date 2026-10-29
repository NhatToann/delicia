import '../../data/services/catalogue_images.dart';
import '../../domain/models/category.dart';
import '../../domain/models/product.dart';
import '../../domain/utils/text_normalizer.dart';

/// Maps a catalogue category onto the artwork that represents it.
///
/// The catalogue in Firebase is written in Vietnamese, so the *display name*
/// (`Category.category` / `Productsdb.category`) is no longer a stable key —
/// it changes with the language of the data. The `categoryId` is: it is an
/// ASCII slug that never changes and that the database indexes
/// (`orderByChild('categoryId')`).
///
/// Resolution order for a product's photo:
///   1. the row's own `picture` — always wins, so tapping a card opens the
///      exact dish the customer saw;
///   2. the artwork of its `categoryId`;
///   3. the artwork of its category *name*, matched accent-insensitively so
///      a legacy row that only carries a name still resolves;
///   4. the demo asset pool.
///
/// Every fallback here is a remote HTTPS URL, so the app never falls back to
/// a hardcoded local photo path for a dish.
class CategoryAssets {
  const CategoryAssets._();

  /// Fallback photo for a product, keyed by category id.
  ///
  /// The values are absolute remote URLs for each category's artwork.
  static const Map<String, String> photoByCategoryId = <String, String>{
    'cat_burger': 'https://delicia-60e0a.web.app/categories/burgers.jpg',
    'cat_chicken': 'https://images.unsplash.com/photo-1730900737724-5b752e1ed3dd?auto=format&fit=crop&w=900&q=85',
    'cat_pizza': 'https://delicia-60e0a.web.app/categories/pizza.jpg',
    'cat_asian': 'https://delicia-60e0a.web.app/categories/japanese.jpg',
    'cat_healthy': 'https://delicia-60e0a.web.app/categories/salads.jpg',
    'cat_dessert': 'https://delicia-60e0a.web.app/categories/desserts.jpg',
    'cat_drink': 'https://delicia-60e0a.web.app/categories/drinks.jpg',
    // Legacy ids from `scripts/seed_catalog.json`.
    'c1': 'https://delicia-60e0a.web.app/categories/burgers.jpg',
    'c2': 'https://delicia-60e0a.web.app/categories/pizza.jpg',
    'c3': 'https://delicia-60e0a.web.app/categories/drinks.jpg',
    'c4': 'https://delicia-60e0a.web.app/categories/desserts.jpg',
    'c5': 'https://delicia-60e0a.web.app/categories/salads.jpg',
    'c6': 'https://delicia-60e0a.web.app/categories/mexican.jpg',
    'c7': 'https://delicia-60e0a.web.app/categories/japanese.jpg',
    'c8': 'https://delicia-60e0a.web.app/categories/italian.jpg',
  };

  /// Pill icon for a category, keyed by category id.
  ///
  /// These are UI glyphs (not dish photos), so they stay local SVG assets.
  static const Map<String, String> iconByCategoryId = <String, String>{
    'cat_burger': 'cat_snacks.svg',
    'cat_chicken': 'cat_snacks.svg',
    'cat_pizza': 'cat_meals.svg',
    'cat_asian': 'cat_vegan.svg',
    'cat_healthy': 'cat_vegan.svg',
    'cat_dessert': 'cat_desserts.svg',
    'cat_drink': 'cat_drinks.svg',
    'c1': 'cat_snacks.svg',
    'c2': 'cat_meals.svg',
    'c3': 'cat_drinks.svg',
    'c4': 'cat_desserts.svg',
    'c5': 'cat_vegan.svg',
    'c6': 'cat_meals.svg',
    'c7': 'cat_vegan.svg',
    'c8': 'cat_meals.svg',
  };

  /// Fallback for rows whose `categoryId` is unknown — matched on the
  /// *normalised* category name.
  ///
  /// Keys are lower-cased and stripped of diacritics, so one entry covers
  /// both the old English names ("Burger") and the Vietnamese ones
  /// ("Bánh Burger"). This is what keeps rows written before the
  /// Vietnamese migration rendering correctly.
  static const Map<String, String> photoByName = <String, String>{
    'burger': 'https://delicia-60e0a.web.app/categories/burgers.jpg',
    'banh burger': 'https://delicia-60e0a.web.app/categories/burgers.jpg',
    'pizza': 'https://delicia-60e0a.web.app/categories/pizza.jpg',
    'drink': 'https://delicia-60e0a.web.app/categories/drinks.jpg',
    'drinks': 'https://delicia-60e0a.web.app/categories/drinks.jpg',
    'do uong': 'https://delicia-60e0a.web.app/categories/drinks.jpg',
    'coffee': 'https://delicia-60e0a.web.app/categories/drinks.jpg',
    'ca phe': 'https://delicia-60e0a.web.app/categories/drinks.jpg',
    'dessert': 'https://delicia-60e0a.web.app/categories/desserts.jpg',
    'desserts': 'https://delicia-60e0a.web.app/categories/desserts.jpg',
    'trang mieng': 'https://delicia-60e0a.web.app/categories/desserts.jpg',
    'salad': 'https://delicia-60e0a.web.app/categories/salads.jpg',
    'vegan': 'https://delicia-60e0a.web.app/categories/salads.jpg',
    'mon chay': 'https://delicia-60e0a.web.app/categories/salads.jpg',
    'healthy': 'https://delicia-60e0a.web.app/categories/salads.jpg',
    'mon lanh manh': 'https://delicia-60e0a.web.app/categories/salads.jpg',
    'meal': 'https://delicia-60e0a.web.app/categories/italian.jpg',
    'mon chinh': 'https://delicia-60e0a.web.app/categories/italian.jpg',
    'pasta': 'https://delicia-60e0a.web.app/categories/italian.jpg',
    'mon y': 'https://delicia-60e0a.web.app/categories/italian.jpg',
    'asian': 'https://delicia-60e0a.web.app/categories/japanese.jpg',
    'mon a': 'https://delicia-60e0a.web.app/categories/japanese.jpg',
    'sushi': 'https://delicia-60e0a.web.app/categories/japanese.jpg',
    'mon nhat': 'https://delicia-60e0a.web.app/categories/japanese.jpg',
    'snacks': 'https://delicia-60e0a.web.app/categories/burgers.jpg',
    'mon an vat': 'https://delicia-60e0a.web.app/categories/burgers.jpg',
    'tacos': 'https://delicia-60e0a.web.app/categories/mexican.jpg',
    'mon mexico': 'https://delicia-60e0a.web.app/categories/mexican.jpg',
    'fries': 'https://delicia-60e0a.web.app/categories/burgers.jpg',
  };

  /// Pill icon for a category whose `categoryId` is unknown — matched on
  /// the normalised category name.
  static const Map<String, String> iconByName = <String, String>{
    'burger': 'cat_snacks.svg',
    'banh burger': 'cat_snacks.svg',
    'pizza': 'cat_meals.svg',
    'drink': 'cat_drinks.svg',
    'drinks': 'cat_drinks.svg',
    'do uong': 'cat_drinks.svg',
    'coffee': 'cat_drinks.svg',
    'ca phe': 'cat_drinks.svg',
    'dessert': 'cat_desserts.svg',
    'desserts': 'cat_desserts.svg',
    'trang mieng': 'cat_desserts.svg',
    'salad': 'cat_vegan.svg',
    'vegan': 'cat_vegan.svg',
    'mon chay': 'cat_vegan.svg',
    'healthy': 'cat_vegan.svg',
    'mon lanh manh': 'cat_vegan.svg',
    'meal': 'cat_meals.svg',
    'mon chinh': 'cat_meals.svg',
    'pasta': 'cat_meals.svg',
    'mon y': 'cat_meals.svg',
    'asian': 'cat_vegan.svg',
    'mon a': 'cat_vegan.svg',
    'sushi': 'cat_vegan.svg',
    'mon nhat': 'cat_vegan.svg',
    'snacks': 'cat_snacks.svg',
    'mon an vat': 'cat_snacks.svg',
    'tacos': 'cat_snacks.svg',
    'mon mexico': 'cat_snacks.svg',
    'fries': 'cat_snacks.svg',
  };

  /// The photo that represents a product.
  static String photoFor(Productsdb product, {int slotIndex = 0}) {
    if (product.picture.trim().isNotEmpty) return product.picture;

    final byId = photoByCategoryId[product.categoryId];
    if (byId != null) return byId;

    final byName = photoByName[normalize(product.category)];
    if (byName != null) return byName;

    return pool[slotIndex.abs() % pool.length];
  }

  /// The pill icon that represents a category.
  ///
  /// Falls back to the row's `icon` field — that field is an icon *slug*
  /// (`burger`, `pizza`, `drink`…), not display copy, so it stays ASCII.
  static String iconFor(Category category) {
    final byId = iconByCategoryId[category.id];
    if (byId != null) return byId;

    final byName = iconByName[normalize(category.category)];
    if (byName != null) return byName;

    return switch (category.icon.toLowerCase()) {
      'pizza' => 'cat_meals.svg',
      'burger' || 'hamburger' => 'cat_snacks.svg',
      'drink' || 'drinks' => 'cat_drinks.svg',
      'dessert' || 'desserts' => 'cat_desserts.svg',
      _ => 'cat_vegan.svg',
    };
  }

  /// Lower-cases a label and strips its diacritics, so "Bánh Burger" and
  /// "Burger" collapse onto the same lookup key.
  static String normalize(String value) =>
      collapseWhitespace(stripDiacritics(value));

  /// Deterministic last-resort artwork pool.
  ///
  /// These are catalogue photo URLs, so even a row that carries no
  /// `picture` still renders food rather than a placeholder box.
  static const List<String> pool = <String>[
    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=900&q=85',
    'https://images.unsplash.com/photo-1692737580547-b45bb4a02356?auto=format&fit=crop&w=900&q=85',
    'https://images.unsplash.com/photo-1604259596863-57153177d40b?auto=format&fit=crop&w=900&q=85',
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=900&q=85',
  ];

  /// The URL of a hosted catalogue image, derived from its file name.
  ///
  /// Used by the seed/migration tooling so the URLs written to Firebase
  /// are built from one place.
  static String url(String fileName) => CatalogueImages.url(fileName);
}
