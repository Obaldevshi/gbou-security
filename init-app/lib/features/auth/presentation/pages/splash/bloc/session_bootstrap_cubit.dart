import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/auth/domain/usecases/restore_session_usecase.dart';

part 'session_bootstrap_state.dart';

@injectable
class SessionBootstrapCubit extends Cubit<SessionBootstrapState> {
  SessionBootstrapCubit(this._restoreSessionUsecase)
    : super(const SessionBootstrapInitial());

  final RestoreSessionUsecase _restoreSessionUsecase;

  Future<void> restore() async {
    if (state is SessionBootstrapLoading) return;
    emit(const SessionBootstrapLoading());
    final result = await _restoreSessionUsecase();
    result.fold(
      (failure) => emit(SessionBootstrapFailure(failure)),
      (_) => emit(const SessionBootstrapComplete()),
    );
  }
}
