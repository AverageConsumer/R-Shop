import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> translations;

  setUpAll(() {
    en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
  });

  Set<String> translationKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  final locales = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb') && !f.path.endsWith('app_en.arb'))
      .toList();

  for (final file in locales) {
    group(file.uri.pathSegments.last, () {
      setUp(() {
        translations =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      });

      test('locale has all EN keys', () {
        final enKeys = translationKeys(en);
        final localeKeys = translationKeys(translations);
        final missing = enKeys.difference(localeKeys);
        expect(missing, isEmpty,
            reason: 'Keys in EN but missing in locale: $missing');
      });

      test('locale has no extra keys beyond EN', () {
        final enKeys = translationKeys(en);
        final localeKeys = translationKeys(translations);
        final extra = localeKeys.difference(enKeys);
        expect(extra, isEmpty, reason: 'Keys in locale but not in EN: $extra');
      });

      test('locale strings contain all EN placeholders', () {
        final mismatches = <String>[];
        for (final key in en.keys) {
          if (key.startsWith('@') && key != '@@locale') {
            final meta = en[key] as Map<String, dynamic>?;
            if (meta == null) continue;
            final placeholders =
                (meta['placeholders'] as Map<String, dynamic>?)?.keys ?? [];
            final translationKey = key.substring(1); // strip leading @
            final translationValue = translations[translationKey] as String?;
            if (translationValue == null) continue;
            for (final p in placeholders) {
              if (!translationValue.contains('{$p}') &&
                  !translationValue.contains('{$p,')) {
                mismatches.add('$translationKey: missing {$p} in locale');
              }
            }
          }
        }
        expect(mismatches, isEmpty,
            reason: 'Placeholder mismatches: ${mismatches.join("; ")}');
      });

      test('no empty translations in locale', () {
        final empty = <String>[];
        for (final key in translations.keys) {
          if (key.startsWith('@') || key == '@@locale') continue;
          final value = translations[key];
          if (value is String && value.trim().isEmpty) {
            empty.add(key);
          }
        }
        expect(empty, isEmpty, reason: 'Empty locale translations: $empty');
      });
    });
  }
}
