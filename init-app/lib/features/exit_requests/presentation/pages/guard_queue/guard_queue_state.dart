import 'package:equatable/equatable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';

enum GuardQueueStatus { initial, loading, success, failure }

class GuardQueueState extends Equatable {
  const GuardQueueState({
    this.status = GuardQueueStatus.initial,
    this.requests = const [],
    this.history = const [],
    this.releasingIds = const {},
    this.isRefreshing = false,
    this.feedbackRevision = 0,
    this.failure,
    this.feedbackCode,
  });

  final GuardQueueStatus status;
  final List<ExitRequest> requests;
  final List<ExitRequest> history;
  final Set<int> releasingIds;
  final bool isRefreshing;
  final Failure? failure;
  final String? feedbackCode;
  final int feedbackRevision;

  GuardQueueState copyWith({
    GuardQueueStatus? status,
    List<ExitRequest>? requests,
    List<ExitRequest>? history,
    Set<int>? releasingIds,
    bool? isRefreshing,
    Failure? failure,
    String? feedbackCode,
    int? feedbackRevision,
    bool clearFailure = false,
    bool clearFeedback = false,
  }) => GuardQueueState(
    status: status ?? this.status,
    requests: requests ?? this.requests,
    history: history ?? this.history,
    releasingIds: releasingIds ?? this.releasingIds,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    failure: clearFailure ? null : failure ?? this.failure,
    feedbackCode: clearFeedback ? null : feedbackCode ?? this.feedbackCode,
    feedbackRevision: feedbackRevision ?? this.feedbackRevision,
  );

  @override
  List<Object?> get props => [
    status,
    requests,
    history,
    releasingIds,
    isRefreshing,
    failure,
    feedbackCode,
    feedbackRevision,
  ];
}
