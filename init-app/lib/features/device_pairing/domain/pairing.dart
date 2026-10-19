import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';

class PairingChoice {
  const PairingChoice(this.id, this.name);
  final int id;
  final String name;
}

class PairingSession {
  const PairingSession(
    this.token,
    this.expiresAt, {
    this.passwordChangeRequired = false,
  });
  final String token;
  final DateTime expiresAt;
  final bool passwordChangeRequired;
}

class PairingPreview {
  const PairingPreview(this.label, this.fingerprint, this.expiresAt);
  final String label, fingerprint;
  final DateTime expiresAt;
}

class PairedDevice {
  const PairedDevice(
    this.id,
    this.label,
    this.role,
    this.state,
    this.buildingId,
  );
  final String id, label, role, state;
  final int? buildingId;
}

class PairingSchool {
  const PairingSchool(
    this.hostname,
    this.generation,
    this.buildings,
    this.devices, {
    this.campuses = const [],
  });
  final String hostname;
  final int generation;
  final List<PairingChoice> buildings;
  final List<PairedDevice> devices;
  final List<PairingCampus> campuses;
  bool get hasPrimary =>
      devices.any((d) => d.role == 'primary' && d.state == 'active');
  bool hasPrimaryFor(int? building) =>
      building != null &&
      devices.any(
        (d) =>
            d.buildingId == building &&
            d.role == 'primary' &&
            d.state == 'active',
      );
  String? hostnameFor(int? building) {
    if (campuses.isEmpty) return hostname;
    for (final campus in campuses) {
      if (campus.buildingId == building) return campus.hostname;
    }
    return null;
  }

  int? generationFor(String deviceId) {
    if (campuses.isEmpty) return generation;
    for (final device in devices) {
      if (device.id != deviceId) continue;
      for (final campus in campuses) {
        if (campus.buildingId == device.buildingId) return campus.generation;
      }
    }
    return null;
  }
}

class PairingCampus {
  const PairingCampus(this.buildingId, this.hostname, this.generation);
  final int buildingId, generation;
  final String hostname;
}

abstract interface class PairingRepository {
  Future<Either<Failure, PairingSession>> changePassword(
    String token,
    String password,
  );
  Future<Either<Failure, PairingSession>> login(String login, String password);
  Future<Either<Failure, List<PairingChoice>>> schools(String token);
  Future<Either<Failure, PairingSchool>> school(String token, int school);
  Future<Either<Failure, PairingPreview>> inspect(String token, String request);
  Future<Either<Failure, PairingSchool>> approve(
    String token,
    String request,
    int school,
    int building,
    String role,
    String code,
  );
  Future<Either<Failure, PairingSchool>> activate(
    String token,
    int school,
    String device,
    int generation,
  );
  Future<Either<Failure, PairingSchool>> revoke(
    String token,
    int school,
    String device,
  );
}

class PairingActions {
  const PairingActions(this.repository);
  final PairingRepository repository;
  Future<Either<Failure, PairingSession>> changePassword(
    String token,
    String password,
  ) => repository.changePassword(token, password);
  Future<Either<Failure, PairingSession>> login(
    String login,
    String password,
  ) => repository.login(login, password);
  Future<Either<Failure, List<PairingChoice>>> schools(String token) =>
      repository.schools(token);
  Future<Either<Failure, PairingSchool>> school(String token, int id) =>
      repository.school(token, id);
  Future<Either<Failure, PairingPreview>> inspect(String token, String id) =>
      repository.inspect(token, id);
  Future<Either<Failure, PairingSchool>> approve(
    String token,
    String request,
    int school,
    int building,
    String role,
    String code,
  ) => repository.approve(token, request, school, building, role, code);
  Future<Either<Failure, PairingSchool>> activate(
    String token,
    int school,
    String device,
    int generation,
  ) => repository.activate(token, school, device, generation);
  Future<Either<Failure, PairingSchool>> revoke(
    String token,
    int school,
    String device,
  ) => repository.revoke(token, school, device);
}
