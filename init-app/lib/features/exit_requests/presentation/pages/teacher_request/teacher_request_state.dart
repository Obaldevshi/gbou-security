import 'package:equatable/equatable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';

enum RequestLoadStatus { initial, loading, success, failure }

enum RequestSubmissionStatus { idle, submitting, success, failure }

class TeacherRequestState extends Equatable {
  const TeacherRequestState({
    this.classesStatus = RequestLoadStatus.initial,
    this.classes = const [],
    this.studentsStatus = RequestLoadStatus.initial,
    this.students = const [],
    this.submissionStatus = RequestSubmissionStatus.idle,
    this.customReason = '',
    this.selectedClass,
    this.selectedStudentIds = const [],
    this.selectedReason,
    this.scheduledAt,
    this.failure,
    this.lastCreatedRequests = const [],
  });

  final RequestLoadStatus classesStatus;
  final List<TeacherClass> classes;
  final RequestLoadStatus studentsStatus;
  final List<Student> students;
  final RequestSubmissionStatus submissionStatus;
  final TeacherClass? selectedClass;
  final List<int> selectedStudentIds;
  final ExitReasonType? selectedReason;
  final String customReason;
  final DateTime? scheduledAt;
  final Failure? failure;
  final List<ExitRequest> lastCreatedRequests;

  bool get isSubmitting =>
      submissionStatus == RequestSubmissionStatus.submitting;

  bool get canSubmit {
    final reasonValid =
        selectedReason != null &&
        (selectedReason != ExitReasonType.other ||
            customReason.trim().length >= 3);
    final timeValid =
        scheduledAt != null &&
        !scheduledAt!.isBefore(
          DateTime.now().subtract(const Duration(minutes: 1)),
        );
    return classesStatus == RequestLoadStatus.success &&
        selectedClass != null &&
        selectedStudentIds.isNotEmpty &&
        reasonValid &&
        timeValid &&
        !isSubmitting;
  }

  TeacherRequestState copyWith({
    RequestLoadStatus? classesStatus,
    List<TeacherClass>? classes,
    RequestLoadStatus? studentsStatus,
    List<Student>? students,
    RequestSubmissionStatus? submissionStatus,
    TeacherClass? selectedClass,
    List<int>? selectedStudentIds,
    ExitReasonType? selectedReason,
    String? customReason,
    DateTime? scheduledAt,
    Failure? failure,
    List<ExitRequest>? lastCreatedRequests,
    bool clearSelectedClass = false,
    bool clearSelectedStudents = false,
    bool clearSelectedReason = false,
    bool clearScheduledAt = false,
    bool clearFailure = false,
    bool clearLastCreatedRequests = false,
  }) => TeacherRequestState(
    classesStatus: classesStatus ?? this.classesStatus,
    classes: classes ?? this.classes,
    studentsStatus: studentsStatus ?? this.studentsStatus,
    students: students ?? this.students,
    submissionStatus: submissionStatus ?? this.submissionStatus,
    selectedClass: clearSelectedClass
        ? null
        : selectedClass ?? this.selectedClass,
    selectedStudentIds: clearSelectedStudents
        ? const []
        : selectedStudentIds ?? this.selectedStudentIds,
    selectedReason: clearSelectedReason
        ? null
        : selectedReason ?? this.selectedReason,
    customReason: customReason ?? this.customReason,
    scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
    failure: clearFailure ? null : failure ?? this.failure,
    lastCreatedRequests: clearLastCreatedRequests
        ? const []
        : lastCreatedRequests ?? this.lastCreatedRequests,
  );

  @override
  List<Object?> get props => [
    classesStatus,
    classes,
    studentsStatus,
    students,
    submissionStatus,
    selectedClass,
    selectedStudentIds,
    selectedReason,
    customReason,
    scheduledAt,
    failure,
    lastCreatedRequests,
  ];
}
