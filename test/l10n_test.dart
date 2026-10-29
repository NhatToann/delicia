import 'dart:convert';
import 'dart:io';

import 'package:delicia/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the localisation contract.
///
/// A mass refactor can silently regress in three ways:
///  1. the ARB file and the generated class drift apart;
///  2. a screen keeps a hardcoded English string;
///  3. a new ARB entry is accidentally written in English.
///
/// These tests read `lib/l10n/app_vi.arb` directly so every key is covered,
/// including ones added after this file was written.
void main() {
  final arbFile = File('lib/l10n/app_vi.arb');
  final generatedFile = File('lib/l10n/generated/app_localizations.dart');

  late Map<String, dynamic> arb;
  late String generatedSource;
  late Set<String> arbKeys;
  late Set<String> generatedKeys;

  setUpAll(() {
    arb = jsonDecode(arbFile.readAsStringSync()) as Map<String, dynamic>;
    generatedSource = generatedFile.readAsStringSync();

    arbKeys = arb.keys
        .where((k) => !k.startsWith('@'))
        .toSet();

    // The generated class declares plain values as `String get key;` and
    // placeholder values as `String key(args);`.
    final getters = RegExp(r'\bget\s+([A-Za-z_]\w*)\s*;')
        .allMatches(generatedSource)
        .map((m) => m.group(1)!);
    final methods = RegExp(r'\bString\s+([A-Za-z_]\w*)\s*\(')
        .allMatches(generatedSource)
        .map((m) => m.group(1)!);
    generatedKeys = <String>{...getters, ...methods}
      ..remove('localeName')
      ..remove('hashCode')
      ..remove('toString');
  });

  group('AppLocalizations', () {
    test('Vietnamese is the only supported locale', () {
      expect(AppLocalizations.supportedLocales, const <Locale>[Locale('vi')]);
    });

    test('lookupAppLocalizations returns the Vietnamese implementation', () {
      final l10n = lookupAppLocalizations(const Locale('vi'));
      expect(l10n.localeName, 'vi');
    });

    test('placeholder keys interpolate their arguments', () {
      final l10n = lookupAppLocalizations(const Locale('vi'));
      expect(l10n.authResendIn(60), 'Gửi lại sau 60s');
      expect(l10n.homeItemCount(3), '3 món');
      expect(l10n.cartBadgeLabel(2), 'Giỏ hàng, 2 món');
      expect(l10n.mapArrivesInMinutes(12), 'Đến nơi sau 12 phút');
      expect(l10n.timeMinutesAgo(5), '5 phút trước');
      expect(l10n.ordersOrderNumber('A1'), 'Đơn #A1');
    });

    test('every ARB key exists in the generated class', () {
      final missing = arbKeys.difference(generatedKeys).toList()..sort();
      expect(missing, isEmpty,
          reason: 'ARB keys without a generated getter:\n${missing.join('\n')}');
    });

    test('the generated class exposes no key missing from the ARB', () {
      final orphans = generatedKeys.difference(arbKeys).toList()..sort();
      expect(orphans, isEmpty,
          reason: 'Generated getters without an ARB entry:\n'
              '${orphans.join('\n')}');
    });

    test('every user-facing ARB value is written in Vietnamese', () {
      // Brand names and acronyms that are intentionally Latin.
      const allowedExact = <String>{
        'Delicia',
        'Email',
        'OK',
        'Xong',
        'PAYPAL',
        'GOOGLE PAY',
        'MERCADO PAGO',
        'PAYOS',
      };
      // Vietnamese is written with these diacritics; a value with letters but
      // no diacritic at all is almost certainly still English.
      const vietnameseLetters =
          'àáảãạăằắẳẵặâầấẩẫậ'
          'èéẻẽẹêềếểễệ'
          'ìíỉĩị'
          'òóỏõọôồốổỗộơờớởỡợ'
          'ùúủũụưừứửữự'
          'ỳýỷỹỵđ'
          'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬ'
          'ÈÉẺẼẸÊỀẾỂỄỆ'
          'ÌÍỈĨỊ'
          'ÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢ'
          'ÙÚỦŨỤƯỪỨỬỮỰ'
          'ỲÝỶỸỴĐ';
      final hasVietnameseDiacritics = RegExp('[$vietnameseLetters]');
      final latinLetters = RegExp('[A-Za-z]');
      final placeholder = RegExp(r'\{\w+\}');

      final offenders = <String>[];
      for (final entry in arb.entries.where((e) => !e.key.startsWith('@'))) {
        final value = entry.value;
        if (value is! String || value.trim().isEmpty) continue;
        if (allowedExact.contains(value)) continue;
        // Pure templates such as "{greeting}, {name}" carry no prose.
        final prose = value.replaceAll(placeholder, '').trim();
        if (!latinLetters.hasMatch(prose)) continue;
        if (!hasVietnameseDiacritics.hasMatch(prose)) {
          offenders.add('${entry.key} = "$value"');
        }
      }
      expect(offenders, isEmpty,
          reason: 'ARB values that are not Vietnamese:\n'
              '${offenders.join('\n')}');
    });

    test('every ARB value is non-empty and placeholders are declared', () {
      for (final entry in arb.entries.where((e) => !e.key.startsWith('@'))) {
        expect(entry.value, isA<String>(), reason: '${entry.key} must be text');
        expect((entry.value as String).trim(), isNotEmpty,
            reason: '${entry.key} is empty');
      }
      for (final entry in arb.entries.where((e) => e.key.startsWith('@'))) {
        if (entry.key.startsWith('@@')) continue; // @@locale and friends
        expect(entry.value, isA<Map<String, dynamic>>(),
            reason: '${entry.key} must be an ARB metadata object');
      }
    });

    test('placeholder metadata is present for every interpolating value', () {
      final missing = <String>[];
      for (final entry in arb.entries.where((e) => !e.key.startsWith('@'))) {
        final value = entry.value as String;
        final placeholders = RegExp(r'\{(\w+)\}').allMatches(value);
        if (placeholders.isEmpty) continue;
        final metadata = arb['@${entry.key}'];
        if (metadata is! Map<String, dynamic>) {
          missing.add('${entry.key} (no metadata)');
          continue;
        }
        final declared = (metadata['placeholders'] as Map?)?.keys.cast<String>() ??
            const <String>[];
        for (final p in placeholders) {
          if (!declared.contains(p.group(1))) {
            missing.add('${entry.key}.${p.group(1)}');
          }
        }
      }
      expect(missing, isEmpty,
          reason: 'Undeclared placeholders:\n${missing.join('\n')}');
    });
  });
}
