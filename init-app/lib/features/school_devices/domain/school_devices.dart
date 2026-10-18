import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';

class SchoolDevice {
  const SchoolDevice({
    required this.id,
    required this.label,
    required this.role,
    required this.state,
  });
  final String id, label, role, state;
}

class SchoolDeviceOverview {
  const SchoolDeviceOverview({
    required this.hostname,
    required this.generation,
    required this.devices,
  });
  final String hostname;
  final int generation;
  final List<SchoolDevice> devices;
}

class DeviceInvitation {
  const DeviceInvitation(this.code, this.expiresAt);
  final String code;
  final DateTime expiresAt;
}

abstract interface class SchoolDevicesRepository {
  Future<Either<Failure, SchoolDeviceOverview>> load(int school);
  Future<Either<Failure, DeviceInvitation>> invite(int school, String role);
  Future<Either<Failure, SchoolDeviceOverview>> activate(
    int school,
    String device,
    int generation,
  );
  Future<Either<Failure, SchoolDeviceOverview>> revoke(
    int school,
    String device,
  );
}

class SchoolDeviceActions {
  const SchoolDeviceActions(this.repository, this.schoolId);
  final SchoolDevicesRepository repository;
  final int schoolId;
  Future<Either<Failure, SchoolDeviceOverview>> load() =>
      repository.load(schoolId);
  Future<Either<Failure, DeviceInvitation>> invite(String role) =>
      repository.invite(schoolId, role);
  Future<Either<Failure, SchoolDeviceOverview>> activate(
    String device,
    int generation,
  ) => repository.activate(schoolId, device, generation);
  Future<Either<Failure, SchoolDeviceOverview>> revoke(String device) =>
      repository.revoke(schoolId, device);
}
