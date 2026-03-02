import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/source_provider.dart';

void main() {
  group('SourceConnectionResult', () {
    test('ok() creates successful result without warning', () {
      const result = SourceConnectionResult.ok();

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.warning, isNull);
    });

    test('ok() with warning preserves warning string', () {
      const result = SourceConnectionResult.ok(
        warning: 'Server responded slowly',
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.warning, 'Server responded slowly');
    });

    test('failed() creates unsuccessful result with error', () {
      const result = SourceConnectionResult.failed('Connection refused');

      expect(result.success, isFalse);
      expect(result.error, 'Connection refused');
      expect(result.warning, isNull);
    });

    test('failed() with empty error string', () {
      const result = SourceConnectionResult.failed('');

      expect(result.success, isFalse);
      expect(result.error, '');
    });
  });
}
