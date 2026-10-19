import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';

class SchoolDestination {
  const SchoolDestination({required this.schoolId, required this.origin});
  final int schoolId;
  final String origin;
}

abstract interface class SchoolDirectoryRepository {
  Future<Either<Failure, SchoolDestination>> resolve(String login);
}
