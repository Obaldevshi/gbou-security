import 'package:json_annotation/json_annotation.dart';
import 'package:mobile_template/features/auth/data/models/current_user_response.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';

part 'auth_login_response.g.dart';

@JsonSerializable(createToJson: false)
class AuthLoginResponse {
  const AuthLoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'token_type')
  final String tokenType;
  @JsonKey(name: 'expires_in')
  final int expiresIn;
  final CurrentUserResponse user;

  factory AuthLoginResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthLoginResponseFromJson(json);

  AuthSession toDomain() => AuthSession(
    accessToken: accessToken,
    tokenType: tokenType,
    expiresIn: expiresIn,
    user: user.toDomain(),
  );
}
