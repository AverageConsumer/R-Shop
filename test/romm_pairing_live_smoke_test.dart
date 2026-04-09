@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/services/romm_pairing_service.dart';

/// Smoke test against a live RomM 4.8+ server.
///
/// Run with: `flutter test --tags live test/romm_pairing_live_smoke_test.dart`
///
/// Assumes a RomM instance is reachable at http://localhost:8090. Skipped by
/// default so CI doesn't break.
void main() {
  const baseUrl = 'http://localhost:8090';

  test('probeServer returns RomM 4.8+ version', () async {
    final svc = RommPairingService();
    final version = await svc.probeServer(baseUrl);
    expect(version, isNotNull, reason: 'RomM not reachable at $baseUrl');
    expect(version, startsWith('4.'));
  });

  test('exchangeCode with bogus code throws RommPairCodeExpiredException',
      () async {
    final svc = RommPairingService();
    expect(
      () => svc.exchangeCode(serverUrl: baseUrl, code: 'XXXX-XXXX'),
      throwsA(isA<RommPairCodeExpiredException>()),
    );
  });

  test('parseQrPayload roundtrips a server-generated pair URL', () {
    final svc = RommPairingService();
    final result = svc.parseQrPayload('$baseUrl/pair?code=B7K9-3MX2');
    expect(result.serverUrl, baseUrl);
    expect(result.code, 'B7K9-3MX2');
  });
}
