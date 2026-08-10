part of 'session_bootstrap_cubit.dart';

sealed class SessionBootstrapState extends Equatable {
  const SessionBootstrapState();

  @override
  List<Object> get props => [];
}

final class SessionBootstrapInitial extends SessionBootstrapState {
  const SessionBootstrapInitial();
}

final class SessionBootstrapLoading extends SessionBootstrapState {
  const SessionBootstrapLoading();
}

final class SessionBootstrapComplete extends SessionBootstrapState {
  const SessionBootstrapComplete();
}

final class SessionBootstrapFailure extends SessionBootstrapState {
  const SessionBootstrapFailure(this.failure);

  final Failure failure;

  @override
  List<Object> get props => [failure];
}
