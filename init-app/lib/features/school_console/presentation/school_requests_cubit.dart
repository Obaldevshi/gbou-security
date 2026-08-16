import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_school_exit_requests_usecase.dart';

enum SchoolRequestsStatus { initial, loading, success, failure }

class SchoolRequestsState extends Equatable {
  const SchoolRequestsState({
    this.status = SchoolRequestsStatus.initial,
    this.active = const [],
    this.history = const [],
    this.failure,
  });
  final SchoolRequestsStatus status;
  final List<ExitRequest> active;
  final List<ExitRequest> history;
  final Failure? failure;
  @override
  List<Object?> get props => [status, active, history, failure];
}

@injectable
class SchoolRequestsCubit extends Cubit<SchoolRequestsState> {
  SchoolRequestsCubit(this.getRequests) : super(const SchoolRequestsState());
  final GetSchoolExitRequestsUsecase getRequests;
  Timer? timer;
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(
        SchoolRequestsState(
          status: SchoolRequestsStatus.loading,
          active: state.active,
          history: state.history,
        ),
      );
    }
    final result = await getRequests();
    if (isClosed) return;
    result.fold(
      (f) => emit(
        SchoolRequestsState(
          status: SchoolRequestsStatus.failure,
          active: state.active,
          history: state.history,
          failure: f,
        ),
      ),
      (data) => emit(
        SchoolRequestsState(
          status: SchoolRequestsStatus.success,
          active: data.active,
          history: data.history,
        ),
      ),
    );
  }

  void start() {
    load();
    timer?.cancel();
    timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => load(silent: true),
    );
  }

  @override
  Future<void> close() {
    timer?.cancel();
    return super.close();
  }
}
