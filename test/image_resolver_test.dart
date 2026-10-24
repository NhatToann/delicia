// UC-02 — ImageResolver unit tests. Verifies that DB-relative picture
// values are mapped to the bundled asset paths the app ships with.

import 'package:delicia/presentation/helpers/image_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageResolver.resolveAssetPath', () {
    test('relative path is joined with the assets root', () {
      expect(
        ImageResolver.resolveAssetPath('products/burger-classic.jpg'),
        'assets/products/burger-classic.jpg',
      );
    });

    test('leading slash is stripped', () {
      expect(
        ImageResolver.resolveAssetPath('/products/burger-classic.jpg'),
        'assets/products/burger-classic.jpg',
      );
    });

    test('absolute asset path is returned untouched', () {
      expect(
        ImageResolver.resolveAssetPath('assets/products/burger-classic.jpg'),
        'assets/products/burger-classic.jpg',
      );
    });

    test('http(s) URL returns null (caller uses Image.network)', () {
      expect(
        ImageResolver.resolveAssetPath('https://example.com/img.jpg'),
        isNull,
      );
      expect(
        ImageResolver.resolveAssetPath('http://example.com/img.jpg'),
        isNull,
      );
    });

    test('empty value returns null (caller falls back)', () {
      expect(ImageResolver.resolveAssetPath(''), isNull);
      expect(ImageResolver.resolveAssetPath('   '), isNull);
    });
  });
}
