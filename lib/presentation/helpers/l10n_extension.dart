import 'package:flutter/widgets.dart';

import '../../domain/services/app_failure.dart';
import '../../l10n/generated/app_localizations.dart';
import 'error_localizer.dart';

/// Sugar for `AppLocalizations.of(context)`.
///
/// Every widget that needs a translated string calls `context.l10n` instead
/// of repeating the `of` lookup, and the `!` keeps call sites free of the
/// `?.` / `!` dance that `AppLocalizations.of` forces.
///
/// ## Why this does not crash when the delegate is missing
///
/// `AppLocalizations.of` returns `null` when no `Localizations` scope with
/// the app delegate is mounted above the widget. That happens in widget
/// tests that pump a bare `MaterialApp` (without `localizationsDelegates`)
/// and in preview/storybook-style harnesses.
///
/// Rather than forcing every test harness in the repo to install
/// `AppLocalizations.delegate` — a change that touches 20+ test files and
/// silently couples them to the l10n layer — the extension falls back to a
/// directly-constructed Vietnamese instance. The strings are identical, so
/// the rendered output does not change; only the *source* of the instance
/// differs.
///
/// The fallback is created lazily and cached, so it is allocated at most
/// once per isolate.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      _fallbackLocalizations;

  /// Translates a domain failure into a sentence the customer can read.
  String failure(AppFailure error) => localizeFailure(l10n, error);
}

/// Vietnamese strings used when no `Localizations` scope is mounted.
///
/// Built through the generated [lookupAppLocalizations], so it always
/// matches the ARB file — there is no second copy of the copy to drift.
AppLocalizations get _fallbackLocalizations =>
    _fallback ??= lookupAppLocalizations(const Locale('vi'));

AppLocalizations? _fallback;

/// The Vietnamese strings, without needing a [BuildContext].
///
/// Use this from code that cannot reach a context — top-level validators,
/// static helpers, model extensions. It returns the very same Vietnamese
/// copy the widgets render.
AppLocalizations get viL10n => _fallbackLocalizations;
