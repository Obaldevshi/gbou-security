import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/cancel_school_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_school_exit_requests_usecase.dart';
import 'package:mobile_template/features/exit_requests/data/request_events_service.dart';
import 'package:mobile_template/core/di/di.dart';

enum SchoolRequestsStatus { initial, loading, success, failure }

class SchoolRequestsState extends Equatable {
  const SchoolRequestsState({
    this.status = SchoolRequestsStatus.initial,
    this.active = const [],
    this.history = const [],
    this.failure,
    this.feedback,
    this.feedbackRevision = 0,
  });
  final SchoolRequestsStatus status;
  final List<ExitRequest> active;
  final List<ExitRequest> history;
  final Failure? failure;
  final String? feedback;
  final int feedbackRevision;
  @override
  List<Object?> get props => [
    status,
    active,
    history,
    failure,
    feedback,
    feedbackRevision,
  ];
}

@injectable
class SchoolRequestsCubit extends Cubit<SchoolRequestsState> {
  SchoolRequestsCubit(this.getRequests, this.cancelRequest)
    : super(const SchoolRequestsState());
  final GetSchoolExitRequestsUsecase getRequests;
  final CancelSchoolExitRequestUsecase cancelRequest;
  StreamSubscription<void>? subscription;
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
    subscription?.cancel();
    subscription = getIt<RequestEventsService>().watch().listen(
      (_) => load(silent: true),
    );
  }

  Future<void> cancel(int requestId) async {
    final result = await cancelRequest(requestId);
    if (isClosed) return;
    await result.fold(
      (failure) async => emit(
        SchoolRequestsState(
          status: SchoolRequestsStatus.success,
          active: state.active,
          history: state.history,
          failure: failure,
          feedback: failure.message,
          feedbackRevision: state.feedbackRevision + 1,
        ),
      ),
      (_) async {
        await load(silent: true);
        if (isClosed) return;
        emit(
          SchoolRequestsState(
            status: SchoolRequestsStatus.success,
            active: state.active,
            history: state.history,
            feedback: 'Заявка отменена',
            feedbackRevision: state.feedbackRevision + 1,
          ),
        );
      },
    );
  }

  @override
  Future<void> close() {
    subscription?.cancel();
    return super.close();
  }
}
