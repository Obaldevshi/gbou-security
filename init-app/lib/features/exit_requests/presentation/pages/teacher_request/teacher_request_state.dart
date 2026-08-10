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
    this.selectedStudent,
    this.selectedReason,
    this.scheduledAt,
    this.failure,
    this.lastCreated,
  });

  final RequestLoadStatus classesStatus;
  final List<TeacherClass> classes;
  final RequestLoadStatus studentsStatus;
  final List<Student> students;
  final RequestSubmissionStatus submissionStatus;
  final TeacherClass? selectedClass;
  final Student? selectedStudent;
  final ExitReasonType? selectedReason;
  final String customReason;
  final DateTime? scheduledAt;
  final Failure? failure;
  final ExitRequest? lastCreated;

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
        selectedStudent != null &&
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
    Student? selectedStudent,
    ExitReasonType? selectedReason,
    String? customReason,
    DateTime? scheduledAt,
    Failure? failure,
    ExitRequest? lastCreated,
    bool clearSelectedClass = false,
    bool clearSelectedStudent = false,
    bool clearSelectedReason = false,
    bool clearScheduledAt = false,
    bool clearFailure = false,
    bool clearLastCreated = false,
  }) => TeacherRequestState(
    classesStatus: classesStatus ?? this.classesStatus,
    classes: classes ?? this.classes,
    studentsStatus: studentsStatus ?? this.studentsStatus,
    students: students ?? this.students,
    submissionStatus: submissionStatus ?? this.submissionStatus,
    selectedClass: clearSelectedClass
        ? null
        : selectedClass ?? this.selectedClass,
    selectedStudent: clearSelectedStudent
        ? null
        : selectedStudent ?? this.selectedStudent,
    selectedReason: clearSelectedReason
        ? null
        : selectedReason ?? this.selectedReason,
    customReason: customReason ?? this.customReason,
    scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
    failure: clearFailure ? null : failure ?? this.failure,
    lastCreated: clearLastCreated ? null : lastCreated ?? this.lastCreated,
  );

  @override
  List<Object?> get props => [
    classesStatus,
    classes,
    studentsStatus,
    students,
    submissionStatus,
    selectedClass,
    selectedStudent,
    selectedReason,
    customReason,
    scheduledAt,
    failure,
    lastCreated,
  ];
}
