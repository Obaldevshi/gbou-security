import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_guard_queue_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/release_exit_request_usecase.dart';

import 'guard_queue_state.dart';

@injectable
class GuardQueueCubit extends Cubit<GuardQueueState> {
  GuardQueueCubit(this._getGuardQueue, this._releaseExitRequest)
    : super(const GuardQueueState());

  final GetGuardQueueUsecase _getGuardQueue;
  final ReleaseExitRequestUsecase _releaseExitRequest;
  bool _isFetching = false;

  Future<void> loadQueue({bool background = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    final hasData = state.status == GuardQueueStatus.success;
    emit(
      state.copyWith(
        status: hasData || background ? state.status : GuardQueueStatus.loading,
        isRefreshing: hasData && background,
        clearFailure: true,
        clearFeedback: !background,
      ),
    );

    final results = await Future.wait([
      _getGuardQueue(),
      _getGuardQueue.history(),
    ]);
    _isFetching = false;
    if (isClosed) return;
    final queueResult = results[0];
    final historyResult = results[1];
    queueResult.fold(
      (failure) {
        if (state.requests.isEmpty && !hasData) {
          emit(
            state.copyWith(
              status: GuardQueueStatus.failure,
              isRefreshing: false,
              failure: failure,
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            status: GuardQueueStatus.success,
            isRefreshing: false,
            failure: failure,
            feedbackCode: 'queue_refresh_failed',
            feedbackRevision: state.feedbackRevision + 1,
          ),
        );
      },
      (requests) => historyResult.fold(
        (failure) => emit(
          state.copyWith(
            status: GuardQueueStatus.success,
            requests: requests,
            isRefreshing: false,
            failure: failure,
          ),
        ),
        (history) => emit(
          state.copyWith(
            status: GuardQueueStatus.success,
            requests: requests,
            history: history,
            isRefreshing: false,
            clearFailure: true,
            clearFeedback: !background,
          ),
        ),
      ),
    );
  }

  Future<void> release(int requestId) async {
    if (state.releasingIds.contains(requestId)) return;
    emit(
      state.copyWith(
        releasingIds: {...state.releasingIds, requestId},
        clearFailure: true,
        clearFeedback: true,
      ),
    );
    final result = await _releaseExitRequest(requestId);
    if (isClosed) return;
    result.fold(
      (failure) {
        final stale =
            failure.errorCode == 'request_already_processed' ||
            failure.errorCode == 'request_not_available';
        emit(
          state.copyWith(
            requests: stale
                ? state.requests
                      .where((request) => request.id != requestId)
                      .toList()
                : state.requests,
            releasingIds: {...state.releasingIds}..remove(requestId),
            failure: failure,
            feedbackCode: stale ? failure.errorCode : 'release_failed',
            feedbackRevision: state.feedbackRevision + 1,
          ),
        );
      },
      (_) {
        emit(
          state.copyWith(
            requests: state.requests
                .where((request) => request.id != requestId)
                .toList(),
            releasingIds: {...state.releasingIds}..remove(requestId),
            feedbackCode: 'release_success',
            feedbackRevision: state.feedbackRevision + 1,
            clearFailure: true,
          ),
        );
        loadQueue(background: true);
      },
    );
  }
}
