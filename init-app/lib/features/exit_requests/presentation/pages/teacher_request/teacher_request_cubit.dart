import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/create_exit_request_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_class_students_usecase.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_classes_usecase.dart';

import 'teacher_request_state.dart';

@injectable
class TeacherRequestCubit extends Cubit<TeacherRequestState> {
  TeacherRequestCubit(
    this._getTeacherClasses,
    this._getClassStudents,
    this._createExitRequest,
  ) : super(const TeacherRequestState());

  final GetTeacherClassesUsecase _getTeacherClasses;
  final GetClassStudentsUsecase _getClassStudents;
  final CreateExitRequestUsecase _createExitRequest;
  int _studentRequestGeneration = 0;

  Future<void> loadClasses() async {
    emit(
      state.copyWith(
        classesStatus: RequestLoadStatus.loading,
        clearFailure: true,
      ),
    );
    final result = await _getTeacherClasses();
    result.fold(
      (failure) => emit(
        state.copyWith(
          classesStatus: RequestLoadStatus.failure,
          failure: failure,
        ),
      ),
      (classes) {
        emit(state.copyWith(
          classesStatus: RequestLoadStatus.success,
          classes: classes,
          clearFailure: true,
        ));
        if (classes.isNotEmpty && state.selectedClass == null) {
          selectClass(classes.first);
        }
      },
    );
  }

  Future<void> selectClass(TeacherClass? schoolClass) async {
    final generation = ++_studentRequestGeneration;
    emit(
      state.copyWith(
        selectedClass: schoolClass,
        clearSelectedClass: schoolClass == null,
        clearSelectedStudent: true,
        students: const [],
        studentsStatus: schoolClass == null
            ? RequestLoadStatus.initial
            : RequestLoadStatus.loading,
        submissionStatus: RequestSubmissionStatus.idle,
        clearFailure: true,
        clearLastCreated: true,
      ),
    );
    if (schoolClass == null) return;

    final result = await _getClassStudents(schoolClass.id);
    if (generation != _studentRequestGeneration ||
        state.selectedClass?.id != schoolClass.id) {
      return;
    }
    result.fold(
      (failure) => emit(
        state.copyWith(
          studentsStatus: RequestLoadStatus.failure,
          failure: failure,
        ),
      ),
      (students) => emit(
        state.copyWith(
          studentsStatus: RequestLoadStatus.success,
          students: students,
          clearFailure: true,
        ),
      ),
    );
  }

  void selectStudent(Student? student) {
    emit(
      state.copyWith(
        selectedStudent: student,
        clearSelectedStudent: student == null,
        submissionStatus: RequestSubmissionStatus.idle,
        clearFailure: true,
        clearLastCreated: true,
      ),
    );
  }

  void selectReason(ExitReasonType? reason) {
    emit(
      state.copyWith(
        selectedReason: reason,
        clearSelectedReason: reason == null,
        customReason: reason == ExitReasonType.other ? state.customReason : '',
        submissionStatus: RequestSubmissionStatus.idle,
        clearFailure: true,
        clearLastCreated: true,
      ),
    );
  }

  void setCustomReason(String value) {
    emit(
      state.copyWith(
        customReason: value,
        submissionStatus: RequestSubmissionStatus.idle,
        clearFailure: true,
        clearLastCreated: true,
      ),
    );
  }

  void setScheduledAt(DateTime value) {
    emit(
      state.copyWith(
        scheduledAt: value,
        submissionStatus: RequestSubmissionStatus.idle,
        clearFailure: true,
        clearLastCreated: true,
      ),
    );
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;
    final command = CreateExitRequestCommand(
      classId: state.selectedClass!.id,
      studentId: state.selectedStudent!.id,
      reasonType: state.selectedReason!,
      customReason: state.selectedReason == ExitReasonType.other
          ? state.customReason.trim()
          : null,
      scheduledAt: state.scheduledAt!,
    );
    emit(
      state.copyWith(
        submissionStatus: RequestSubmissionStatus.submitting,
        clearFailure: true,
        clearLastCreated: true,
      ),
    );
    final result = await _createExitRequest(command);
    result.fold(
      (failure) => emit(
        state.copyWith(
          submissionStatus: RequestSubmissionStatus.failure,
          failure: failure,
        ),
      ),
      (request) => emit(
        state.copyWith(
          submissionStatus: RequestSubmissionStatus.success,
          customReason: '',
          lastCreated: request,
          clearSelectedStudent: true,
          clearSelectedReason: true,
          clearScheduledAt: true,
          clearFailure: true,
        ),
      ),
    );
  }
}
