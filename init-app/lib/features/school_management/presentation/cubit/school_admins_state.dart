import 'package:equatable/equatable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';

enum SchoolAdminsStatus { initial, loading, success, failure }

class SchoolAdminsState extends Equatable {
  const SchoolAdminsState({
    this.status = SchoolAdminsStatus.initial,
    this.schools = const [],
    this.admins = const [],
    this.busyIds = const {},
    this.isSaving = false,
    this.feedbackRevision = 0,
    this.failure,
    this.feedback,
  });
  final SchoolAdminsStatus status;
  final List<School> schools;
  final List<SchoolAdmin> admins;
  final Set<int> busyIds;
  final bool isSaving;
  final Failure? failure;
  final String? feedback;
  final int feedbackRevision;

  SchoolAdminsState copyWith({
    SchoolAdminsStatus? status,
    List<School>? schools,
    List<SchoolAdmin>? admins,
    Set<int>? busyIds,
    bool? isSaving,
    Failure? failure,
    String? feedback,
    int? feedbackRevision,
    bool clearFailure = false,
    bool clearFeedback = false,
  }) => SchoolAdminsState(
    status: status ?? this.status,
    schools: schools ?? this.schools,
    admins: admins ?? this.admins,
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
    admins,
    busyIds,
    isSaving,
    failure,
    feedback,
    feedbackRevision,
  ];
}
