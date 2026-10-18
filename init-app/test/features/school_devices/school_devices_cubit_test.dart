import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/school_devices/data/school_devices_repository.dart';
import 'package:mobile_template/features/school_devices/domain/school_devices.dart';
import 'package:mobile_template/features/school_devices/presentation/school_devices_cubit.dart';

void main() {
  test(
    'loads the school address and retains it while hiding an invitation',
    () async {
      final cubit = SchoolDevicesCubit(
        SchoolDeviceActions(MockSchoolDevicesRepository(), 236),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.overview!.hostname, '236.gbousecurity.ru');
      expect(cubit.state.busy, isFalse);
      await cubit.invite('terminal');
      expect(cubit.state.invitation!.code, startsWith('DEMO-ONLY'));
      cubit.hideInvitation();
      expect(cubit.state.invitation, isNull);
      expect(cubit.state.overview!.devices.single.role, 'primary');
      expect(cubit.state.overview!.hostname, '236.gbousecurity.ru');
    },
  );

  test(
    'activation without a loaded overview cannot call the repository',
    () async {
      final cubit = SchoolDevicesCubit(
        SchoolDeviceActions(MockSchoolDevicesRepository(), 236),
      );
      addTearDown(cubit.close);
      await cubit.activate('pending');
      expect(cubit.state.overview, isNull);
      expect(cubit.state.busy, isFalse);
    },
  );
}
