// Widget test for the search-result keyword highlight.
//
// The highlight has to survive Vietnamese diacritics: the query is typed
// by a customer ("bun bo"), the product name is written by the catalogue
// ("Bún Bò"), and the customer must still see where the match is.

import 'package:delicia/presentation/client/search/widgets/highlighted_text.dart';
import 'package:delicia/presentation/themes/colors_frave.dart';
import 'package:delicia/presentation/themes/type_frave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The leaf spans of a rendered [HighlightedText].
///
/// [Text.rich] wraps the given span in another one (Flutter applies the
/// effective text style to it), so the tree is two levels deep. This
/// helper flattens it and returns the runs that actually paint the text.
List<TextSpan> _spans(WidgetTester tester) {
  final richText = tester.widget<RichText>(find.byType(RichText));
  final leaves = <TextSpan>[];

  void walk(InlineSpan span) {
    if (span is! TextSpan) return;
    final children = span.children;
    if (children == null || children.isEmpty) {
      if (span.text != null) leaves.add(span);
      return;
    }
    for (final child in children) {
      walk(child);
    }
  }

  walk(richText.text as TextSpan);
  return leaves;
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 200, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the plain text when there is no query', (tester) async {
    await tester.pumpWidget(_wrap(
      const HighlightedText(text: 'Burger Nấm', query: ''),
    ));

    expect(find.text('Burger Nấm'), findsOneWidget);
  });

  testWidgets('renders the plain text when the query does not occur',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const HighlightedText(text: 'Burger Nấm', query: 'pizza'),
    ));

    expect(find.text('Burger Nấm'), findsOneWidget);
  });

  testWidgets('splits the text around the match', (tester) async {
    await tester.pumpWidget(_wrap(
      const HighlightedText(text: 'Burger Nấm Truffle', query: 'truffle'),
    ));

    // The matched run is its own span, the rest stays plain.
    final spans = _spans(tester);
    expect(spans.length, 2);
    expect(spans[0].text, 'Burger Nấm ');
    expect(spans[1].text, 'Truffle');
  });

  testWidgets('highlights a match regardless of case', (tester) async {
    await tester.pumpWidget(_wrap(
      const HighlightedText(text: 'Burger Nấm', query: 'BURGER'),
    ));

    final spans = _spans(tester);
    expect(spans.length, 2);
    expect(spans[0].text, 'Burger');
    expect(spans[1].text, ' Nấm');
  });

  testWidgets('highlights a match despite the diacritics', (tester) async {
    await tester.pumpWidget(_wrap(
      const HighlightedText(text: 'Bún Bò', query: 'bun bo'),
    ));

    // "bun bo" is two tokens, so "Bún" and "Bò" are highlighted separately
    // and the space between them stays plain.
    final spans = _spans(tester);
    expect(spans.length, 3);
    expect(spans[0].text, 'Bún');
    expect(spans[1].text, ' ');
    expect(spans[2].text, 'Bò');
  });

  testWidgets('highlights every occurrence of the query', (tester) async {
    await tester.pumpWidget(_wrap(
      const HighlightedText(text: 'Burger Burger', query: 'burger'),
    ));

    // "Burger" + " " + "Burger" → three spans.
    expect(_spans(tester).length, 3);
  });

  testWidgets('highlights each token of a multi-word query', (tester) async {
    await tester.pumpWidget(_wrap(
      const HighlightedText(text: 'Burger Nấm Truffle', query: 'truffle nấm'),
    ));

    // "Burger " + "Nấm" + " " + "Truffle"
    expect(_spans(tester).length, 4);
  });

  testWidgets('the highlighted run uses the highlight style', (tester) async {
    await tester.pumpWidget(_wrap(
      const HighlightedText(
        text: 'Burger Nấm',
        query: 'burger',
        style: TextStyle(fontSize: 13),
      ),
    ));

    final highlighted = _spans(tester)
        .firstWhere((s) => s.text == 'Burger')
        .style as TextStyle;
    expect(highlighted.backgroundColor, ColorsFrave.pillYellow);
    expect(highlighted.color, ColorsFrave.navOrange);
  });

  testWidgets('uses the product card title style by default', (tester) async {
    await tester.pumpWidget(_wrap(
      const HighlightedText(text: 'Burger', query: ''),
    ));

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style?.fontFamily, FraveText.family);
  });
}
