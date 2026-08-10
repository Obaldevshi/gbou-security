import 'package:equatable/equatable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';

enum TeacherRequestsStatus { initial, loading, success, failure }

class TeacherRequestsState extends Equatable {
  const TeacherRequestsState({
    this.status = TeacherRequestsStatus.initial,
    this.active = const [],
    this.history = const [],
    this.isRefreshing = false,
    this.feedbackRevision = 0,
    this.failure,
    this.feedbackCode,
  });

  final TeacherRequestsStatus status;
  final List<ExitRequest> active;
  final List<ExitRequest> history;
  final bool isRefreshing;
  final Failure? failure;
  final String? feedbackCode;
  final int feedbackRevision;

  TeacherRequestsState copyWith({
    TeacherRequestsStatus? status,
    List<ExitRequest>? active,
    List<ExitRequest>? history,
    bool? isRefreshing,
    Failure? failure,
    String? feedbackCode,
    int? feedbackRevision,
    bool clearFailure = false,
    bool clearFeedback = false,
  }) => TeacherRequestsState(
    status: status ?? this.status,
    active: active ?? this.active,
    history: history ?? this.history,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    failure: clearFailure ? null : failure ?? this.failure,
    feedbackCode: clearFeedback ? null : feedbackCode ?? this.feedbackCode,
    feedbackRevision: feedbackRevision ?? this.feedbackRevision,
  );

  @override
  List<Object?> get props => [
    status,
    active,
    history,
    isRefreshing,
    failure,
    feedbackCode,
    feedbackRevision,
  ];
}
