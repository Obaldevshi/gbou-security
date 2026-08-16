import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/usecases/school_class_usecases.dart';
import 'package:mobile_template/features/school_console/domain/usecases/student_usecases.dart';

enum ManagedStudentsStatus { initial, loading, success, failure }

class SchoolStudentsState extends Equatable {
  const SchoolStudentsState({
    this.status = ManagedStudentsStatus.initial,
    this.classes = const [],
    this.students = const [],
    this.busyIds = const {},
    this.isSaving = false,
    this.isImporting = false,
    this.revision = 0,
    this.failure,
    this.feedback,
    this.classFilter,
  });
  final ManagedStudentsStatus status;
  final List<ManagedSchoolClass> classes;
  final List<ManagedStudent> students;
  final Set<int> busyIds;
  final bool isSaving;
  final bool isImporting;
  final int revision;
  final Failure? failure;
  final String? feedback;
  final int? classFilter;
  SchoolStudentsState copyWith({
    ManagedStudentsStatus? status,
    List<ManagedSchoolClass>? classes,
    List<ManagedStudent>? students,
    Set<int>? busyIds,
    bool? isSaving,
    bool? isImporting,
    int? revision,
    Failure? failure,
    String? feedback,
    int? classFilter,
    bool clearClassFilter = false,
    bool clearFailure = false,
    bool clearFeedback = false,
  }) => SchoolStudentsState(
    status: status ?? this.status,
    classes: classes ?? this.classes,
    students: students ?? this.students,
    busyIds: busyIds ?? this.busyIds,
    isSaving: isSaving ?? this.isSaving,
    isImporting: isImporting ?? this.isImporting,
    revision: revision ?? this.revision,
    failure: clearFailure ? null : failure ?? this.failure,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
    classFilter: clearClassFilter ? null : classFilter ?? this.classFilter,
  );
  @override
  List<Object?> get props => [
    status,
    classes,
    students,
    busyIds,
    isSaving,
    isImporting,
    revision,
    failure,
    feedback,
    classFilter,
  ];
}

@injectable
class SchoolStudentsCubit extends Cubit<SchoolStudentsState> {
  SchoolStudentsCubit(
    this.getClasses,
    this.getStudents,
    this.createStudent,
    this.updateStudent,
    this.setStatus,
    this.deleteStudent,
    this.importStudents,
  ) : super(const SchoolStudentsState());
  final GetManagedClassesUsecase getClasses;
  final GetManagedStudentsUsecase getStudents;
  final CreateManagedStudentUsecase createStudent;
  final UpdateManagedStudentUsecase updateStudent;
  final SetManagedStudentStatusUsecase setStatus;
  final DeleteManagedStudentUsecase deleteStudent;
  final ImportManagedStudentsUsecase importStudents;
  Future<void> load({int? classId, bool clearFilter = false}) async {
    emit(
      state.copyWith(
        status: ManagedStudentsStatus.loading,
        classFilter: classId,
        clearClassFilter: clearFilter,
        clearFailure: true,
      ),
    );
    final classesResult = await getClasses();
    final studentsResult = await getStudents(
      classId: clearFilter ? null : classId ?? state.classFilter,
    );
    if (isClosed) return;
    Failure? failure;
    List<ManagedSchoolClass>? classes;
    List<ManagedStudent>? students;
    classesResult.fold((item) => failure = item, (item) => classes = item);
    studentsResult.fold((item) => failure ??= item, (item) => students = item);
    failure == null
        ? emit(
            state.copyWith(
              status: ManagedStudentsStatus.success,
              classes: classes,
              students: students,
              classFilter: clearFilter ? null : classId,
              clearClassFilter: clearFilter,
              clearFailure: true,
            ),
          )
        : emit(
            state.copyWith(
              status: ManagedStudentsStatus.failure,
              failure: failure,
            ),
          );
  }

  Future<bool> save({int? id, required StudentDraft draft}) async {
    if (state.isSaving) return false;
    emit(
      state.copyWith(isSaving: true, clearFailure: true, clearFeedback: true),
    );
    final result = id == null
        ? await createStudent(draft)
        : await updateStudent(id, draft);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        _fail(failure);
        return false;
      },
      (student) {
        final visible =
            state.classFilter == null || state.classFilter == student.classId;
        final items = [...state.students];
        final index = items.indexWhere((item) => item.id == student.id);
        if (visible) {
          index < 0 ? items.add(student) : items[index] = student;
        } else if (index >= 0) {
          items.removeAt(index);
        }
        items.sort((a, b) => a.fullName.compareTo(b.fullName));
        emit(
          state.copyWith(
            students: items,
            isSaving: false,
            feedback: id == null ? 'Ученик добавлен' : 'Ученик обновлён',
            revision: state.revision + 1,
            clearFailure: true,
          ),
        );
        return true;
      },
    );
  }

  Future<void> toggle(ManagedStudent student) async {
    if (state.busyIds.contains(student.id)) return;
    _busy(student.id);
    final result = await setStatus(student.id, !student.isActive);
    if (isClosed) return;
    result.fold(
      _fail,
      (updated) => _replace(
        updated,
        updated.isActive ? 'Ученик включён' : 'Ученик отключён',
      ),
    );
  }

  Future<void> delete(ManagedStudent student) async {
    if (state.busyIds.contains(student.id)) return;
    _busy(student.id);
    final result = await deleteStudent(student.id);
    if (isClosed) return;
    result.fold(
      _fail,
      (_) => emit(
        state.copyWith(
          students: state.students
              .where((item) => item.id != student.id)
              .toList(),
          busyIds: {...state.busyIds}..remove(student.id),
          feedback: 'Ученик удалён',
          revision: state.revision + 1,
          clearFailure: true,
        ),
      ),
    );
  }

  Future<StudentImportSummary?> import(
    String text, {
    bool dryRun = false,
  }) async {
    if (state.isImporting || text.trim().isEmpty) return null;
    emit(
      state.copyWith(
        isImporting: true,
        clearFailure: true,
        clearFeedback: true,
      ),
    );
    final result = await importStudents(text, dryRun: dryRun);
    if (isClosed) return null;
    Failure? failure;
    StudentImportSummary? summary;
    result.fold((item) => failure = item, (item) => summary = item);
    if (failure != null) {
      _fail(failure!);
      emit(state.copyWith(isImporting: false));
      return null;
    }
    if (dryRun) {
      emit(
        state.copyWith(
          isImporting: false,
          feedback: 'Проверка завершена: готово ${summary!.createdCount}',
          revision: state.revision + 1,
          clearFailure: true,
        ),
      );
      return summary;
    }
    final studentsResult = await getStudents(classId: state.classFilter);
    List<ManagedStudent>? students;
    studentsResult.fold((item) => failure = item, (item) => students = item);
    if (failure != null) {
      _fail(failure!);
      emit(state.copyWith(isImporting: false));
      return null;
    }
    emit(
      state.copyWith(
        students: students,
        isImporting: false,
        feedback: 'Добавлено учеников: ${summary!.createdCount}',
        revision: state.revision + 1,
        clearFailure: true,
      ),
    );
    return summary;
  }

  void _busy(int id) => emit(
    state.copyWith(
      busyIds: {...state.busyIds, id},
      clearFeedback: true,
      clearFailure: true,
    ),
  );
  void _replace(ManagedStudent student, String feedback) => emit(
    state.copyWith(
      students: state.students
          .map((item) => item.id == student.id ? student : item)
          .toList(),
      busyIds: {...state.busyIds}..remove(student.id),
      feedback: feedback,
      revision: state.revision + 1,
      clearFailure: true,
    ),
  );
  void _fail(Failure failure) => emit(
    state.copyWith(
      isSaving: false,
      isImporting: false,
      busyIds: const {},
      failure: failure,
      feedback: failure.message.isEmpty
          ? 'Не удалось выполнить действие'
          : failure.message,
      revision: state.revision + 1,
    ),
  );
}
