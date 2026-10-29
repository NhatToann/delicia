import 'package:flutter/material.dart';

import '../../../../domain/utils/text_normalizer.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// Renders [text] with every occurrence of the search [query] highlighted.
///
/// The highlight is accent-insensitive on both sides: the query "bun bo"
/// highlights "Bún Bò", and a query typed in English highlights the
/// Vietnamese name too (the customer typed what they remember).
///
/// When the query does not occur in the text at all — for example when the
/// product matched because of its *description* — the plain text is
/// returned, so the card never renders stray markers.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int maxLines;
  final TextOverflow overflow;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? FraveText.semiBold(13, height: 1.2);
    final ranges = _highlightRanges();
    if (ranges.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return Text.rich(
      TextSpan(children: _buildSpans(ranges, baseStyle)),
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// The character ranges of [text] that match any query token.
  List<({int start, int end})> _highlightRanges() {
    final tokens = _queryTokens();
    if (tokens.isEmpty || text.isEmpty) return const [];

    // Map the accent-stripped text back onto the original indices, so the
    // spans line up with what is actually rendered.
    final stripped = stripDiacritics(text.toLowerCase());
    final ranges = <({int start, int end})>[];

    for (final token in tokens) {
      var from = 0;
      while (from < stripped.length) {
        final index = stripped.indexOf(token, from);
        if (index < 0) break;
        ranges.add((start: index, end: index + token.length));
        from = index + token.length;
      }
    }
    if (ranges.isEmpty) return const [];

    ranges.sort((a, b) => a.start.compareTo(b.start));

    // Merge overlapping ranges so nested tokens do not produce a broken
    // span tree.
    final merged = <({int start, int end})>[];
    for (final range in ranges) {
      if (merged.isNotEmpty && range.start <= merged.last.end) {
        final last = merged.removeLast();
        merged.add((start: last.start, end: range.end > last.end ? range.end : last.end));
      } else {
        merged.add(range);
      }
    }
    return merged;
  }

  /// The query split into accent-stripped tokens.
  List<String> _queryTokens() {
    return query
        .toLowerCase()
        .replaceAll(RegExp(r'[,\/;|]+'), ' ')
        .split(RegExp(r'\s+'))
        .map(stripDiacritics)
        .where((t) => t.isNotEmpty)
        .toList();
  }

  List<TextSpan> _buildSpans(
    List<({int start, int end})> ranges,
    TextStyle baseStyle,
  ) {
    final hlStyle = highlightStyle ??
        baseStyle.copyWith(
          color: ColorsFrave.navOrange,
          backgroundColor: ColorsFrave.pillYellow,
          fontWeight: FontWeight.w800,
        );

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: hlStyle,
        ),
      );
      cursor = range.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}
