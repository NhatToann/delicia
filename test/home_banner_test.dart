// Regression tests for the promo banner on the home screen.
//
// The defect: the banner copy was laid out in a `Column` inside a fixed
// 128 px card. A long Vietnamese headline (`ĐẶC BIỆT TRONG TUẦN` at 30 px
// bold) wrapped onto three lines, the `Column` grew taller than the card
// and Flutter painted the yellow/black overflow stripes over the slide.
//
// The fix keeps the copy inside the card:
//   * the copy column has a 16 px gutter on the left,
//   * the photo panel is inset 12 px on every side and rounded,
//   * the headline is measured through a `FittedBox` so it scales down
//     instead of overflowing.
//
// These tests lock the geometry in so a future copy edit cannot regress it.

import 'package:delicia/presentation/client/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a single [PromoBanner] at the card's real size (323 x 128).
Future<void> _pumpBanner(
  WidgetTester tester, {
  required String headline,
  required String caption,
  Size size = const Size(393, 852),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 323,
            child: PromoBanner(
              imageAsset: 'assets/figma_home/img_banner.png',
              headline: headline,
              caption: caption,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

/// Every Vietnamese headline the carousel can show.
const List<String> _headlines = <String>[
  'GIẢM 30%',
  'BURGER KHỔNG LỒ',
  'PIZZA ĐÚNG VỊ',
  'TƯƠI MỚI & XANH',
  'ĐẶC BIỆT TRONG TUẦN',
];

const List<String> _captions = <String>[
  'Trải nghiệm món mới ngon lành của chúng tôi',
  'Hai miếng thịt, phô mai tan chảy, bánh mì tươi',
  'Nướng đá lò với nhân tươi từ nông trại',
  'Nguyên liệu tuyển chọn, phục vụ trong ngày',
  'Thử thực đơn đặc biệt theo mùa',
];

void main() {
  testWidgets('the longest headline does not overflow the card', (
    WidgetTester tester,
  ) async {
    await _pumpBanner(
      tester,
      headline: 'ĐẶC BIỆT TRONG TUẦN',
      caption: 'Thử thực đơn đặc biệt theo mùa',
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('no carousel slide overflows the banner', (
    WidgetTester tester,
  ) async {
    for (var i = 0; i < _headlines.length; i++) {
      await _pumpBanner(
        tester,
        headline: _headlines[i],
        caption: _captions[i],
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow on slide "${_headlines[i]}"',
      );
    }
  });

  testWidgets('the banner copy stays inside the card with a real gutter', (
    WidgetTester tester,
  ) async {
    await _pumpBanner(
      tester,
      headline: 'ĐẶC BIỆT TRONG TUẦN',
      caption: 'Thử thực đơn đặc biệt theo mùa',
    );

    final card = tester.getRect(find.byType(PromoBanner));
    final headlineRect = tester.getRect(find.text('ĐẶC BIỆT TRONG TUẦN'));
    final captionRect = tester.getRect(find.text('Thử thực đơn đặc biệt theo mùa'));

    // Nothing may poke out of the rounded card.
    expect(headlineRect.left, greaterThanOrEqualTo(card.left));
    expect(headlineRect.right, lessThanOrEqualTo(card.right));
    expect(headlineRect.top, greaterThanOrEqualTo(card.top));
    expect(headlineRect.bottom, lessThanOrEqualTo(card.bottom));
    expect(captionRect.top, greaterThanOrEqualTo(card.top));
    expect(captionRect.bottom, lessThanOrEqualTo(card.bottom));

    // The text must not sit flush against the left edge of the card.
    expect(headlineRect.left - card.left, greaterThanOrEqualTo(8));
    expect(captionRect.left - card.left, greaterThanOrEqualTo(8));

    // The copy must not run into the photo on the right.
    expect(headlineRect.right, lessThan(card.right));
  });

  testWidgets('the banner keeps its 128 px height', (
    WidgetTester tester,
  ) async {
    await _pumpBanner(
      tester,
      headline: 'ĐẶC BIỆT TRONG TUẦN',
      caption: 'Thử thực đơn đặc biệt theo mùa',
    );

    expect(tester.getSize(find.byType(PromoBanner)).height, 128);
  });
}
