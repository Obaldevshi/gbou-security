import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';
import 'package:mobile_template/features/school_management/domain/repositories/school_management_repository.dart';

class MockSchoolManagementRepository implements SchoolManagementRepository {
  final _schools = <School>[
    const School(
      id: 1,
      fullName:
          'Государственное бюджетное образовательное учреждение «Школа № 1»',
      shortName: 'ГБОУ Школа № 1',
      address: 'Москва, Школьная улица, 1',
      isActive: true,
    ),
  ];
  final _admins = <SchoolAdmin>[
    const SchoolAdmin(
      id: 1,
      schoolId: 1,
      login: 'school.admin',
      fullName: 'Администратор школы',
      phone: '+7 900 000-00-00',
      isActive: true,
    ),
  ];
  int _schoolId = 2;
  int _adminId = 2;
  static const _delay = Duration(milliseconds: 250);

  @override
  Future<Either<Failure, List<School>>> getSchools() async {
    await Future<void>.delayed(_delay);
    return Right(List.unmodifiable(_schools));
  }

  @override
  Future<Either<Failure, SystemStats>> getSystemStats() async => Right(
    SystemStats(
      schools: _schools.length,
      activeSchools: _schools.where((item) => item.isActive).length,
      schoolAdmins: _admins.length,
      users: _admins.length + 2,
    ),
  );

  @override
  Future<Either<Failure, School>> createSchool(SchoolDraft draft) async {
    final school = School(
      id: _schoolId++,
      fullName: draft.fullName,
      shortName: draft.shortName,
      address: draft.address,
      isActive: true,
    );
    _schools.add(school);
    return Right(school);
  }

  @override
  Future<Either<Failure, School>> updateSchool(
    int id,
    SchoolDraft draft,
  ) async {
    final old = _schools.firstWhere((item) => item.id == id);
    final school = School(
      id: id,
      fullName: draft.fullName,
      shortName: draft.shortName,
      address: draft.address,
      isActive: old.isActive,
    );
    _schools[_schools.indexOf(old)] = school;
    return Right(school);
  }

  @override
  Future<Either<Failure, School>> setSchoolStatus(int id, bool isActive) async {
    final old = _schools.firstWhere((item) => item.id == id);
    final school = School(
      id: id,
      fullName: old.fullName,
      shortName: old.shortName,
      address: old.address,
      isActive: isActive,
    );
    _schools[_schools.indexOf(old)] = school;
    return Right(school);
  }

  @override
  Future<Either<Failure, Unit>> deleteSchool(int id) async {
    _schools.removeWhere((item) => item.id == id);
    _admins.removeWhere((item) => item.schoolId == id);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<SchoolAdmin>>> getSchoolAdmins() async {
    await Future<void>.delayed(_delay);
    return Right(List.unmodifiable(_admins));
  }

  @override
  Future<Either<Failure, SchoolAdmin>> createSchoolAdmin(
    SchoolAdminDraft draft,
  ) async {
    final admin = SchoolAdmin(
      id: _adminId++,
      schoolId: draft.schoolId,
      login: draft.login,
      fullName: draft.fullName,
      phone: draft.phone,
      isActive: true,
    );
    _admins.add(admin);
    return Right(admin);
  }

  @override
  Future<Either<Failure, SchoolAdmin>> updateSchoolAdmin(
    int id,
    SchoolAdminDraft draft,
  ) async {
    final old = _admins.firstWhere((item) => item.id == id);
    final admin = SchoolAdmin(
      id: id,
      schoolId: draft.schoolId,
      login: draft.login,
      fullName: draft.fullName,
      phone: draft.phone,
      isActive: old.isActive,
    );
    _admins[_admins.indexOf(old)] = admin;
    return Right(admin);
  }

  @override
  Future<Either<Failure, SchoolAdmin>> setSchoolAdminStatus(
    int id,
    bool isActive,
  ) async {
    final old = _admins.firstWhere((item) => item.id == id);
    final admin = SchoolAdmin(
      id: id,
      schoolId: old.schoolId,
      login: old.login,
      fullName: old.fullName,
      phone: old.phone,
      isActive: isActive,
    );
    _admins[_admins.indexOf(old)] = admin;
    return Right(admin);
  }

  @override
  Future<Either<Failure, Unit>> deleteSchoolAdmin(int id) async {
    _admins.removeWhere((item) => item.id == id);
    return const Right(unit);
  }
}
