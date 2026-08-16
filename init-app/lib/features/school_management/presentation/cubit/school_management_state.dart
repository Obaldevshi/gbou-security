import 'package:equatable/equatable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';

enum SchoolManagementStatus { initial, loading, success, failure }

class SchoolManagementState extends Equatable {
  const SchoolManagementState({
    this.status = SchoolManagementStatus.initial,
    this.schools = const [],
    this.busyIds = const {},
    this.isSaving = false,
    this.feedbackRevision = 0,
    this.failure,
    this.feedback,
  });

  final SchoolManagementStatus status;
  final List<School> schools;
  final Set<int> busyIds;
  final bool isSaving;
  final Failure? failure;
  final String? feedback;
  final int feedbackRevision;

  int get activeCount => schools.where((school) => school.isActive).length;
  int get inactiveCount => schools.length - activeCount;

  SchoolManagementState copyWith({
    SchoolManagementStatus? status,
    List<School>? schools,
    Set<int>? busyIds,
    bool? isSaving,
    Failure? failure,
    String? feedback,
    int? feedbackRevision,
    bool clearFailure = false,
    bool clearFeedback = false,
  }) => SchoolManagementState(
    status: status ?? this.status,
    schools: schools ?? this.schools,
    busyIds: busyIds ?? this.busyIds,
    isSaving: isSaving ?? this.isSaving,
    failure: clearFailure ? null : failure ?? this.failure,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
    feedbackRevision: feedbackRevision ?? this.feedbackRevision,
  );

  @override
  List<Object?> get props => [
    status,
    schools,
    busyIds,
    isSaving,
    failure,
    feedback,
    feedbackRevision,
  ];
}
