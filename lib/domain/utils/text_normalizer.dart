/// Text helpers shared by the domain layer.
///
/// The catalogue copy is Vietnamese, but customers still type English words
/// ("burger", "pizza") into the search field, and sometimes they omit the
/// diacritics. Matching therefore has to happen on a *normalised* form of
/// both strings.
///
/// The normalisation strips Vietnamese diacritics so that "Bánh Burger" and
/// "banh burger" collapse onto the same key. It lives in the domain layer
/// (rather than in a presentation helper) because both the product model
/// and the presentation-layer category mapper need it.
library;

/// Removes the diacritics from [value] and lower-cases it.
///
/// Vietnamese precomposed letters (`ệ` = U+1EC7, `ặ` = U+1EB7, …) are
/// single code points, *not* base letter + combining mark, so they need an
/// explicit table. The decomposed NFD form is handled by dropping the
/// combining mark.
///
/// ```dart
/// stripDiacritics('Bánh Burger'); // 'banh burger'
/// stripDiacritics('Tráng Miệng'); // 'trang mieng'
/// ```
String stripDiacritics(String value) {
  final lowered = value.trim().toLowerCase();
  final out = StringBuffer();
  for (final rune in lowered.runes) {
    if (_isCombiningMark(rune)) continue;
    out.write(_baseLetters[rune] ?? String.fromCharCode(rune));
  }
  return out.toString();
}

/// Collapses runs of whitespace into a single space.
///
/// "Burger   Nấm" and "Burger Nấm" should hit the same lookup key.
String collapseWhitespace(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

/// True for the Unicode combining-mark blocks.
///
/// A letter written in NFD form is a base character followed by one of
/// these marks, e.g. `a` + U+0301 for `á`. Dropping the mark leaves the
/// plain letter.
bool _isCombiningMark(int rune) =>
    (rune >= 0x0300 && rune <= 0x036F) || // combining diacritical marks
    (rune >= 0x1AB0 && rune <= 0x1AFF) || // combining diacritical marks ext.
    (rune >= 0x20D0 && rune <= 0x20FF) || // combining diacritical marks sym.
    (rune >= 0xFE20 && rune <= 0xFE2F); // combining half marks

/// Precomposed accented letters → their base letter.
///
/// Written as two parallel strings rather than a map literal so the whole
/// Vietnamese block stays readable on one screen.
/// Accented letters → their base letter.
///
/// One entry per group, so a group can never be silently mis-aligned with
/// its target the way two parallel strings can.
const List<(String, String)> _baseLetterGroups = <(String, String)>[
  ('àáâãäåă', 'a'), // a + ă
  ('ằắẳẵặ', 'a'), // ă's vowels
  ('ạảấầẩẫậ', 'a'), // a's vowels with tone marks
  ('èéêë', 'e'),
  ('ẹẻẽ', 'e'),
  ('ềếệểễ', 'e'),
  ('ìíîï', 'i'),
  ('ịỉĩ', 'i'),
  ('òóôõöơ', 'o'), // o + ơ
  ('ọỏ', 'o'),
  ('ồốổỗộ', 'o'),
  ('ớờởỡợ', 'o'),
  ('ùúûüư', 'u'), // u + ư
  ('ụủ', 'u'),
  ('ừứửữự', 'u'),
  ('ỳýỵỷỹÿ', 'y'),
  ('đ', 'd'),
  ('ç', 'c'),
];

/// Code point → base letter.
///
/// Only the lower-case form is listed: [stripDiacritics] lower-cases its
/// input before looking anything up, so an upper-case code point never
/// reaches this map.
final Map<int, String> _baseLetters = <int, String>{
  for (final (source, base) in _baseLetterGroups)
    for (var i = 0; i < source.length; i++) source.codeUnitAt(i): base,
};
