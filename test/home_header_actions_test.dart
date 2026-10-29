// UC-02 — Home header action tiles.
//
// The Figma home frame (node 47:23) draws three 26 px action tiles to the
// right of the search pill, at x265, x298 and x332. The glyph inside each
// asset decides what the button does:
//
//   x265  action_1.svg  = basket   → the cart drawer
//   x298  action_2.svg  = bell     → notifications / the order history
//   x332  action_3.svg  = person   → the profile drawer
//
// Getting this mapping wrong puts a shopping basket where the profile
// button should be, so the wiring is locked down here.

import 'package:delicia/presentation/client/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the header row and records which action was fired.
Future<List<int>> _pumpHeader(
  WidgetTester tester, {
  void Function()? onProfile,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final fired = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: HomeHeaderRow(
          onFilter: () {},
          onAction: fired.add,
          onProfile: onProfile,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fired;
}

void main() {
  group('HomeHeaderRow — the three action tiles', () {
    testWidgets('the basket tile opens the cart', (tester) async {
      final fired = await _pumpHeader(tester);
      final handle = tester.ensureSemantics();

      expect(find.bySemanticsLabel('Giỏ hàng'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Giỏ hàng'));
      await tester.pumpAndSettle();
      handle.dispose();

      // Index 1 is the basket.
      expect(fired, <int>[1]);
    });

    testWidgets('the bell tile opens the notifications', (tester) async {
      final fired = await _pumpHeader(tester);
      final handle = tester.ensureSemantics();

      expect(find.bySemanticsLabel('Thông báo'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Thông báo'));
      await tester.pumpAndSettle();
      handle.dispose();

      // Index 0 is the bell.
      expect(fired, <int>[0]);
    });

    testWidgets('the person tile opens the profile', (tester) async {
      var profileTaps = 0;
      await _pumpHeader(tester, onProfile: () => profileTaps++);
      final handle = tester.ensureSemantics();

      expect(find.bySemanticsLabel('Hồ sơ của tôi'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Hồ sơ của tôi'));
      await tester.pumpAndSettle();
      handle.dispose();

      expect(profileTaps, 1);
    });

    testWidgets('the filter disc is separate from the action tiles',
        (tester) async {
      final fired = await _pumpHeader(tester);
      final handle = tester.ensureSemantics();

      await tester.tap(find.bySemanticsLabel('Lọc'));
      await tester.pumpAndSettle();
      handle.dispose();

      expect(fired, isEmpty);
    });

    testWidgets('the tiles render the Figma assets in the Figma order',
        (tester) async {
      await _pumpHeader(tester);

      // `SvgPicture` does not expose its asset path, so the four SVGs are
      // identified by the semantics labels of the tiles that own them and
      // by the *order* the widgets are laid out in.
      final handle = tester.ensureSemantics();

      // The filter disc is the leftmost, then the three 26 px tiles.
      final svgOrder = <String>[
        for (final label in <String>['Lọc', 'Giỏ hàng', 'Thông báo', 'Hồ sơ của tôi'])
          _svgOf(tester, label),
      ];

      expect(
        svgOrder[0],
        'assets/figma_home/filter_icon.svg',
        reason: 'the filter disc keeps its own asset',
      );
      expect(
        svgOrder[1],
        'assets/figma_home/action_1.svg',
        reason: 'the basket tile uses action_1',
      );
      expect(
        svgOrder[2],
        'assets/figma_home/action_2.svg',
        reason: 'the bell tile uses action_2',
      );
      expect(
        svgOrder[3],
        'assets/figma_home/action_3.svg',
        reason: 'the person tile uses action_3',
      );

      handle.dispose();
    });
  });
}

/// The asset path of the SVG that belongs to the tile labelled [label].
String _svgOf(WidgetTester tester, String label) {
  // The semantics label sits on the `Semantics` wrapper, so the SVG is
  // found by walking down from the label.
  final svg = find.descendant(
    of: find.bySemanticsLabel(label),
    matching: find.byType(SvgPicture),
  );
  if (svg.evaluate().isEmpty) {
    // Fall back to the enclosing tile.
    final tile = find.ancestor(
      of: find.bySemanticsLabel(label),
      matching: find.byType(GestureDetector),
    );
    final svgInTile = find.descendant(
      of: tile.first,
      matching: find.byType(SvgPicture),
    );
    return _assetOf(tester, svgInTile.first);
  }
  return _assetOf(tester, svg.first);
}

/// Reads the asset path out of the [SvgPicture] at [finder].
///
/// `SvgPicture.asset` stores the path inside its `bytesLoader`
/// (`SvgAssetLoader`), which exposes it as `assetName`.
String _assetOf(WidgetTester tester, Finder finder) {
  final picture = tester.widget<SvgPicture>(finder);
  final loader = picture.bytesLoader;
  if (loader is SvgAssetLoader) return loader.assetName;
  return loader.runtimeType.toString();
}
