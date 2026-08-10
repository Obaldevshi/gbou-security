part of 'login_bloc.dart';

sealed class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object> get props => [];
}

final class LoginInitial extends LoginState {
  const LoginInitial();
}

final class LoginLoading extends LoginState {
  const LoginLoading();
}

final class LoginSuccess extends LoginState {
  const LoginSuccess({required this.session});

  final AuthSession session;

  @override
  List<Object> get props => [session];
}

final class LoginFailure extends LoginState {
  const LoginFailure({required this.failure});

  final Failure failure;

  @override
  List<Object> get props => [failure];
}
