import '../models/product.dart';

/// A live feed of the product catalogue.
///
/// ## Why the catalogue needs a listener
///
/// The catalogue is read from two very different places: the admin
/// console **edits** it, the customer app **reads** it. Every read so far
/// was a one-shot `once()` — the screen kept whatever it fetched when it
/// opened.
///
/// That is exactly why an admin who corrected a price saw the change
/// *inside the edit form* and nowhere else: the list screen, the home
/// screen and the detail screen each held a stale copy of the row, and
/// nothing told them a write had happened.
///
/// A realtime listener closes the gap. The moment a row is written, every
/// open screen re-renders with the new price — no pull-to-refresh, no
/// re-opening the app.
///
/// ## Why it is a separate interface
///
/// The catalogue services have two very different jobs: reading and
/// writing. The *listening* part is an optional capability, so it is
/// declared here rather than being forced onto every implementation. The
/// blocs check for it at runtime:
///
///   * the production Firebase services implement it, so the app listens;
///   * the in-memory test fakes do not, so the tests keep their
///     deterministic, one-shot behaviour.
abstract class CatalogWatcher {
  /// Emits the whole catalogue, starting with the current contents.
  ///
  /// Firebase's `onValue` always fires once when the listener attaches, so
  /// a caller never has to fetch the first snapshot separately.
  Stream<List<Productsdb>> watchProducts();
}
