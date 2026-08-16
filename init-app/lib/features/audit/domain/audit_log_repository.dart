import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/audit/domain/audit_log_entry.dart';

abstract interface class AuditLogRepository {
  Future<Either<Failure, AuditLogPageData>> getLogs({
    required bool schoolOnly,
    required int page,
    String? search,
    String? method,
  });
}
