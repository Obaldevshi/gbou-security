import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_template/core/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '${platform.name}: salted PIN, restart lock, attempt limit and wipe',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        FlutterSecureStorage.setMockInitialValues({});
        SharedPreferences.setMockInitialValues({});
        const storage = FlutterSecureStorage();
        final prefs = await SharedPreferences.getInstance();
        final session = await SessionService.create(storage, prefs);
        expect(session.supportsPin, isTrue);
        await session.configurePin(
          pin: '4729',
          refreshToken: 'synthetic-refresh-token',
          trustedDeviceId: 123,
        );
        final values = await storage.readAll();
        expect(values.values, isNot(contains('4729')));
        expect(values['pin_hash'], isNotEmpty);
        expect(values['pin_salt'], isNotEmpty);
        final restored = await SessionService.create(storage, prefs);
        expect(restored.status, SessionStatus.locked);
        expect(await restored.verifyPin('4729'), PinVerificationResult.success);
        for (var i = 0; i < SessionService.maxPinAttempts - 1; i++) {
          expect(
            await restored.verifyPin('0000'),
            PinVerificationResult.invalid,
          );
        }
        expect(
          await restored.verifyPin('0000'),
          PinVerificationResult.lockedOut,
        );
        expect(restored.getRefreshToken(), isNull);
        expect(restored.hasPinConfigured, isFalse);
        expect((await storage.readAll()).containsKey('pin_hash'), isFalse);
        session.dispose();
        restored.dispose();
      },
    );
  }
  test('desktop and moderation demo do not offer PIN', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final session = await SessionService.create(
      const FlutterSecureStorage(),
      await SharedPreferences.getInstance(),
    );
    expect(session.supportsPin, isFalse);
    expect(SessionService.inMemory().supportsPin, isFalse);
    session.dispose();
  });
}
