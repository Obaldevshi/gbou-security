part of 'login_bloc.dart';

sealed class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object> get props => [];
}

final class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.login, required this.password});

  final String login;
  final String password;

  @override
  List<Object> get props => [login, password];
}
