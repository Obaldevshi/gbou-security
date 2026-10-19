import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/auth/domain/repositories/school_directory_repository.dart';

/// Synthetic fixtures only. Demo authentication itself never leaves the device.
class MockSchoolDirectoryRepository implements SchoolDirectoryRepository {
  const MockSchoolDirectoryRepository();
  @override
  Future<Either<Failure, SchoolDestination>> resolve(String login) async {
    if (const {
      'teacher.demo',
      'guard.demo',
      'school.admin',
    }.contains(login.trim().toLowerCase())) {
      return const Right(
        SchoolDestination(schoolId: 1, origin: 'https://demo.gbousecurity.ru'),
      );
    }
    return const Left(
      ServerFailure(
        message: 'Школа не определена.',
        statusCode: 404,
        errorCode: 'school_not_resolved',
      ),
    );
  }
}
