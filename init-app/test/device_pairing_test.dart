import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/device_pairing/data/pairing_repository.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing.dart';
import 'package:mobile_template/features/device_pairing/presentation/pairing_cubit.dart';

void main() {
  test(
    'QR mock: login, own school, invalid code, approval stays pending',
    () async {
      final cubit = PairingCubit(
        PairingActions(MockPairingRepository()),
        'test-device',
      );
      await cubit.login('admin-demo', 'mock-only');
      expect(cubit.state.schoolId, 1);
      expect(cubit.state.preview, isNotNull);
      expect(cubit.state.school!.buildings.map((b) => b.id).toList(), [1, 2]);
      await cubit.approve(1, 'primary', '000000');
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.preview, isNotNull);
      await cubit.approve(1, 'primary', '123456');
      expect(cubit.state.done, isTrue);
      expect(cubit.state.preview, isNull);
      expect(cubit.state.school!.devices.single.state, 'pending');
      expect(cubit.state.school!.hasPrimary, isFalse);
      await cubit.activate('test-device');
      expect(cubit.state.school!.hasPrimary, isTrue);
      expect(cubit.state.school!.hasPrimaryFor(1), isTrue);
      expect(cubit.state.school!.hasPrimaryFor(2), isFalse);
      cubit.logout();
      expect(cubit.state.session, isNull);
      expect(cubit.state.school, isNull);
      await cubit.close();
    },
  );

  test(
    'Standalone client rejects non-HTTPS and credential-bearing origins',
    () {
      for (final url in [
        'http://central.example/api/v1',
        'https://user:secret@central.example/api/v1',
        'https://central.example/api/v1?token=secret',
        'https://central.example/api/v1/#fragment',
      ]) {
        expect(() => PairingApi(url), throwsArgumentError);
      }
    },
  );
}
