import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/cancel_teacher_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_exit_requests_usecase.dart';

import 'teacher_requests_state.dart';

@injectable
class TeacherRequestsCubit extends Cubit<TeacherRequestsState> {
  TeacherRequestsCubit(this._getTeacherRequests, this._cancelRequest)
    : super(const TeacherRequestsState());

  final GetTeacherExitRequestsUsecase _getTeacherRequests;
  final CancelTeacherExitRequestUsecase _cancelRequest;
  bool _isFetching = false;

  Future<void> load({bool background = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    final hadSnapshot = state.status == TeacherRequestsStatus.success;
    emit(
      state.copyWith(
        status: hadSnapshot || background
            ? state.status
            : TeacherRequestsStatus.loading,
        isRefreshing: hadSnapshot && background,
        clearFailure: true,
        clearFeedback: true,
      ),
    );

    final result = await _getTeacherRequests();
    _isFetching = false;
    if (isClosed) return;
    result.fold(
      (failure) {
        if (!hadSnapshot && state.active.isEmpty && state.history.isEmpty) {
          emit(
            state.copyWith(
              status: TeacherRequestsStatus.failure,
              isRefreshing: false,
              failure: failure,
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            status: TeacherRequestsStatus.success,
            isRefreshing: false,
            failure: failure,
            feedbackCode: 'refresh_failed',
            feedbackRevision: state.feedbackRevision + 1,
          ),
        );
      },
      (snapshot) {
        final previousActiveIds = state.active.map((item) => item.id).toSet();
        final movedToHistory =
            hadSnapshot &&
            snapshot.history.any((item) => previousActiveIds.contains(item.id));
        emit(
          state.copyWith(
            status: TeacherRequestsStatus.success,
            active: snapshot.active,
            history: snapshot.history,
            isRefreshing: false,
            clearFailure: true,
            feedbackCode: movedToHistory ? 'request_released' : null,
            feedbackRevision: movedToHistory
                ? state.feedbackRevision + 1
                : state.feedbackRevision,
            clearFeedback: !movedToHistory,
          ),
        );
      },
    );
  }

  void addCreatedRequest(ExitRequest request) {
    final active =
        [request, ...state.active.where((item) => item.id != request.id)]
          ..sort((a, b) {
            final scheduled = a.scheduledAt.compareTo(b.scheduledAt);
            if (scheduled != 0) return scheduled;
            final created = a.createdAt.compareTo(b.createdAt);
            return created != 0 ? created : a.id.compareTo(b.id);
          });
    emit(
      state.copyWith(
        status: TeacherRequestsStatus.success,
        active: active,
        clearFailure: true,
        clearFeedback: true,
      ),
    );
  }

  Future<void> cancel(int requestId) async {
    final result = await _cancelRequest(requestId);
    if (isClosed) return;
    await result.fold(
      (failure) async => emit(
        state.copyWith(
          failure: failure,
          feedbackCode: 'cancel_failed',
          feedbackRevision: state.feedbackRevision + 1,
        ),
      ),
      (_) async {
        await load(background: true);
        if (isClosed) return;
        emit(
          state.copyWith(
            feedbackCode: 'request_cancelled',
            feedbackRevision: state.feedbackRevision + 1,
          ),
        );
      },
    );
  }
}
