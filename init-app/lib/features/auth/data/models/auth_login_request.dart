import 'package:json_annotation/json_annotation.dart';

part 'auth_login_request.g.dart';

@JsonSerializable()
class AuthLoginRequest {
  const AuthLoginRequest({required this.login, required this.password});

  final String login;
  final String password;

  Map<String, dynamic> toJson() => _$AuthLoginRequestToJson(this);
}
