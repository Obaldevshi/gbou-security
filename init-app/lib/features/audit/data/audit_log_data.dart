import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/error_handler.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/audit/domain/audit_log_entry.dart';
import 'package:mobile_template/features/audit/domain/audit_log_repository.dart';

@lazySingleton
class AuditLogApiDataSource {
  const AuditLogApiDataSource(this.dio, @Named('baseUrl') this.baseUrl);
  final Dio dio;
  final String baseUrl;

  Future<Map<String, dynamic>> getLogs({
    required bool schoolOnly,
    required int page,
    String? search,
    String? method,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$baseUrl/${schoolOnly ? 'school' : 'system'}/audit',
      queryParameters: {
        'page': page,
        'page_size': 25,
        if (search != null && search.isNotEmpty) 'search': search,
        if (method != null && method.isNotEmpty) 'method': method,
      },
    );
    return response.data!['data'] as Map<String, dynamic>;
  }
}

@LazySingleton(as: AuditLogRepository)
class AuditLogRepositoryImpl implements AuditLogRepository {
  const AuditLogRepositoryImpl(this.api);
  final AuditLogApiDataSource api;

  @override
  Future<Either<Failure, AuditLogPageData>> getLogs({
    required bool schoolOnly,
    required int page,
    String? search,
    String? method,
  }) async {
    try {
      final data = await api.getLogs(
        schoolOnly: schoolOnly,
        page: page,
        search: search,
        method: method,
      );
      final items = (data['items'] as List<dynamic>).map((raw) {
        final item = raw as Map<String, dynamic>;
        return AuditLogEntry(
          id: item['id'] as int,
          actorName: item['actor_name'] as String,
          schoolName: item['school_name'] as String?,
          method: item['method'] as String,
          path: item['path'] as String,
          statusCode: item['status_code'] as int,
          ipAddress: item['ip_address'] as String?,
          createdAt: DateTime.parse(item['created_at'] as String).toLocal(),
        );
      }).toList();
      return Right(
        AuditLogPageData(
          items: items,
          total: data['total'] as int,
          page: data['page'] as int,
          pageSize: data['page_size'] as int,
        ),
      );
    } catch (error) {
      return Left(ErrorHandler.handleError(error));
    }
  }
}
