import 'package:equatable/equatable.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';

class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final CurrentUser user;

  @override
  List<Object> get props => [accessToken, tokenType, expiresIn, user];
}
