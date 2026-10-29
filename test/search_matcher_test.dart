// Tests for the leaf search rules shared by the product model and the
// `ProductSearch` ranking engine.
//
// Both entry points must agree, otherwise a row would match in one place
// and not in the other. These tests pin the shared behaviour.

import 'package:delicia/domain/utils/search_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('searchTokens', () {
    test('splits on whitespace', () {
      expect(searchTokens('truffle burger'), ['truffle', 'burger']);
    });

    test('strips the diacritics', () {
      expect(searchTokens('đặc trưng'), ['dac', 'trung']);
    });

    test('lower-cases the tokens', () {
      expect(searchTokens('BURGER'), ['burger']);
    });

    test('treats punctuation as a separator', () {
      expect(searchTokens('pizza, burger'), ['pizza', 'burger']);
      expect(searchTokens('pizza/burger'), ['pizza', 'burger']);
    });

    test('drops empty tokens', () {
      expect(searchTokens('   '), isEmpty);
      expect(searchTokens(''), isEmpty);
      expect(searchTokens('  burger   pho  '), ['burger', 'pho']);
    });
  });

  group('fieldsMatch', () {
    final fields = SearchFields.normalised(
      name: 'Burger Nấm Truffle',
      nameEn: 'Signature Truffle Burger',
      category: 'Bánh Burger',
      description: 'Thịt trộn Wagyu.',
    );

    test('an empty token list matches', () {
      expect(fieldsMatch(fields, const []), isTrue);
    });

    test('a token in the name matches', () {
      expect(fieldsMatch(fields, const ['truffle']), isTrue);
    });

    test('a token in the English name matches', () {
      expect(fieldsMatch(fields, const ['signature']), isTrue);
    });

    test('a token in the category matches', () {
      expect(fieldsMatch(fields, const ['banh']), isTrue);
    });

    test('a token in the description matches', () {
      expect(fieldsMatch(fields, const ['wagyu']), isTrue);
    });

    test('every token has to match', () {
      expect(fieldsMatch(fields, const ['truffle', 'pizza']), isFalse);
      expect(fieldsMatch(fields, const ['truffle', 'burger']), isTrue);
    });

    test('a token that occurs nowhere does not match', () {
      expect(fieldsMatch(fields, const ['xyzzy']), isFalse);
    });
  });

  group('matchStrength', () {
    test('a match at the start has full strength', () {
      expect(matchStrength('burger pho mai', 'burger'), 1.0);
    });

    test('a later match is weaker', () {
      final late = matchStrength(
        'a very long description that mentions burger only at the very end',
        'burger',
      );
      expect(late, lessThan(1.0));
      expect(late, greaterThan(0.0));
    });

    test('a missing token has no strength', () {
      expect(matchStrength('burger', 'pizza'), 0);
    });

    test('an empty text has no strength', () {
      expect(matchStrength('', 'burger'), 0);
    });
  });
}
