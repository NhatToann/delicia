import '../../data/env/environment.dart';

/// Builds the absolute URL of a catalogue image hosted on Firebase.
///
/// The Realtime Database stores the **full URL** of every dish photo in
/// `products/{id}/picture` — there is no hardcoded image path anywhere in
/// the app. This helper only exists to derive that URL from a file name,
/// which the seed/migration tooling uses; the app itself reads the URL
/// straight off the row.
///
/// Keeping the base URL in [Environment] means the whole catalogue can be
/// re-pointed at another Firebase project (or a CDN in front of it) by
/// editing one constant.
class CatalogueImages {
  const CatalogueImages._();

  /// The Firebase-hosted root of the catalogue imagery.
  static String get baseUrl => Environment.catalogueImageBaseUrl;

  /// The absolute URL of [fileName], e.g. `burger-classic.jpg`.
  ///
  /// [fileName] may be given with or without the `.jpg` suffix.
  static String url(String fileName) {
    final name = fileName.trim();
    if (name.isEmpty) return '';
    if (name.startsWith('http://') || name.startsWith('https://')) return name;

    final withExtension =
        name.toLowerCase().endsWith('.jpg') ? name : '$name.jpg';
    return '$baseUrl/$withExtension';
  }
}
