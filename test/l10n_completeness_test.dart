import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, dynamic> en;
  late Map<String, dynamic> de;

  setUpAll(() {
    en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
        as Map<String, dynamic>;
    de = jsonDecode(File('lib/l10n/app_de.arb').readAsStringSync())
        as Map<String, dynamic>;
  });

  Set<String> translationKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('DE has all EN keys', () {
    final enKeys = translationKeys(en);
    final deKeys = translationKeys(de);
    final missing = enKeys.difference(deKeys);
    expect(missing, isEmpty, reason: 'Keys in EN but missing in DE: $missing');
  });

  test('DE has no extra keys beyond EN', () {
    final enKeys = translationKeys(en);
    final deKeys = translationKeys(de);
    final extra = deKeys.difference(enKeys);
    expect(extra, isEmpty, reason: 'Keys in DE but not in EN: $extra');
  });

  test('DE strings contain all EN placeholders', () {
    final mismatches = <String>[];
    for (final key in en.keys) {
      if (key.startsWith('@') && key != '@@locale') {
        final meta = en[key] as Map<String, dynamic>?;
        if (meta == null) continue;
        final placeholders =
            (meta['placeholders'] as Map<String, dynamic>?)?.keys ?? [];
        final translationKey = key.substring(1); // strip leading @
        final deValue = de[translationKey] as String?;
        if (deValue == null) continue;
        for (final p in placeholders) {
          if (!deValue.contains('{$p}') && !deValue.contains('{$p,')) {
            mismatches.add('$translationKey: missing {$p} in DE');
          }
        }
      }
    }
    expect(mismatches, isEmpty,
        reason: 'Placeholder mismatches: ${mismatches.join("; ")}');
  });

  test('no empty translations in DE', () {
    final empty = <String>[];
    for (final key in de.keys) {
      if (key.startsWith('@') || key == '@@locale') continue;
      final value = de[key];
      if (value is String && value.trim().isEmpty) {
        empty.add(key);
      }
    }
    expect(empty, isEmpty, reason: 'Empty DE translations: $empty');
  });
}
