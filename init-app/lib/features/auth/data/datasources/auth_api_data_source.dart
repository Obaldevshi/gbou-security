import 'package:injectable/injectable.dart';
import 'package:mobile_template/data/models/response/base_response.dart';
import 'package:mobile_template/features/auth/data/models/auth_login_request.dart';
import 'package:mobile_template/features/auth/data/models/auth_login_response.dart';
import 'package:mobile_template/features/auth/data/models/current_user_response.dart';
import 'package:retrofit/retrofit.dart';
import 'package:dio/dio.dart';

part 'auth_api_data_source.g.dart';

@lazySingleton
@RestApi()
abstract class AuthApiDataSource {
  @factoryMethod
  factory AuthApiDataSource(Dio dio, {@Named('baseUrl') String? baseUrl}) =
      _AuthApiDataSource;

  @POST('/auth/login')
  Future<BaseResponse<AuthLoginResponse>> login(
    @Body() AuthLoginRequest request,
  );

  @GET('/users/')
  Future<BaseResponse<CurrentUserResponse>> getCurrentUser();
}
