import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/data/models/response/base_response.dart';
import 'package:mobile_template/features/exit_requests/data/models/exit_request_models.dart';
import 'package:retrofit/retrofit.dart';

part 'exit_request_api_data_source.g.dart';

@lazySingleton
@RestApi()
abstract class ExitRequestApiDataSource {
  @factoryMethod
  factory ExitRequestApiDataSource(
    Dio dio, {
    @Named('baseUrl') String? baseUrl,
  }) = _ExitRequestApiDataSource;

  @GET('/teacher/classes')
  Future<BaseResponse<List<TeacherClassResponse>>> getTeacherClasses();

  @GET('/teacher/classes/{classId}/students')
  Future<BaseResponse<List<StudentResponse>>> getClassStudents(
    @Path('classId') int classId,
  );

  @POST('/teacher/exit-requests')
  Future<BaseResponse<ExitRequestResponse>> createExitRequest(
    @Body() CreateExitRequestRequest request,
  );

  @GET('/guard/exit-requests')
  Future<BaseResponse<List<ExitRequestResponse>>> getPendingGuardRequests();

  @GET('/guard/exit-requests/history')
  Future<BaseResponse<List<ExitRequestResponse>>> getGuardHistory();

  @POST('/guard/exit-requests/{requestId}/release')
  Future<BaseResponse<ReleaseExitRequestResponse>> releaseExitRequest(
    @Path('requestId') int requestId,
  );

  @GET('/teacher/exit-requests')
  Future<BaseResponse<TeacherExitRequestsSnapshotResponse>>
  getTeacherExitRequests();

  @GET('/school/exit-requests')
  Future<BaseResponse<TeacherExitRequestsSnapshotResponse>>
  getSchoolExitRequests();

  @POST('/teacher/exit-requests/{requestId}/cancel')
  Future<BaseResponse<ExitRequestStatusResponse>> cancelTeacherExitRequest(
    @Path('requestId') int requestId,
  );

  @POST('/school/exit-requests/{requestId}/cancel')
  Future<BaseResponse<ExitRequestStatusResponse>> cancelSchoolExitRequest(
    @Path('requestId') int requestId,
  );
}
