import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_teacher.dart';
import 'package:mobile_template/features/school_console/domain/usecases/school_class_usecases.dart';
import 'package:mobile_template/features/school_console/domain/usecases/teacher_usecases.dart';

enum ManagedTeachersStatus { initial, loading, success, failure }

class SchoolTeachersState extends Equatable {
  const SchoolTeachersState({
    this.status = ManagedTeachersStatus.initial,
    this.classes = const [],
    this.teachers = const [],
    this.busyIds = const {},
    this.isSaving = false,
    this.isImporting = false,
    this.revision = 0,
    this.failure,
    this.feedback,
  });
  final ManagedTeachersStatus status;
  final List<ManagedSchoolClass> classes;
  final List<ManagedTeacher> teachers;
  final Set<int> busyIds;
  final bool isSaving;
  final bool isImporting;
  final int revision;
  final Failure? failure;
  final String? feedback;
  SchoolTeachersState copyWith({
    ManagedTeachersStatus? status,
    List<ManagedSchoolClass>? classes,
    List<ManagedTeacher>? teachers,
    Set<int>? busyIds,
    bool? isSaving,
    bool? isImporting,
    int? revision,
    Failure? failure,
    String? feedback,
    bool clearFailure = false,
    bool clearFeedback = false,
  }) => SchoolTeachersState(
    status: status ?? this.status,
    classes: classes ?? this.classes,
    teachers: teachers ?? this.teachers,
    busyIds: busyIds ?? this.busyIds,
    isSaving: isSaving ?? this.isSaving,
    isImporting: isImporting ?? this.isImporting,
    revision: revision ?? this.revision,
    failure: clearFailure ? null : failure ?? this.failure,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
  );
  @override
  List<Object?> get props => [
    status,
    classes,
    teachers,
    busyIds,
    isSaving,
    isImporting,
    revision,
    failure,
    feedback,
  ];
}

@injectable
class SchoolTeachersCubit extends Cubit<SchoolTeachersState> {
  SchoolTeachersCubit(
    this.getClasses,
    this.getTeachers,
    this.createTeacher,
    this.updateTeacher,
    this.setStatus,
    this.deleteTeacher,
    this.importTeachers,
  ) : super(const SchoolTeachersState());
  final GetManagedClassesUsecase getClasses;
  final GetManagedTeachersUsecase getTeachers;
  final CreateManagedTeacherUsecase createTeacher;
  final UpdateManagedTeacherUsecase updateTeacher;
  final SetManagedTeacherStatusUsecase setStatus;
  final DeleteManagedTeacherUsecase deleteTeacher;
  final ImportManagedTeachersUsecase importTeachers;

  Future<void> load() async {
    emit(
      state.copyWith(status: ManagedTeachersStatus.loading, clearFailure: true),
    );
    final classesResult = await getClasses();
    final teachersResult = await getTeachers();
    if (isClosed) return;
    Failure? failure;
    List<ManagedSchoolClass>? classes;
    List<ManagedTeacher>? teachers;
    classesResult.fold((item) => failure = item, (item) => classes = item);
    teachersResult.fold((item) => failure ??= item, (item) => teachers = item);
    failure == null
        ? emit(
            state.copyWith(
              status: ManagedTeachersStatus.success,
              classes: classes,
              teachers: teachers,
              clearFailure: true,
            ),
          )
        : emit(
            state.copyWith(
              status: ManagedTeachersStatus.failure,
              failure: failure,
            ),
          );
  }

  Future<bool> save({int? id, required TeacherDraft draft}) async {
    if (state.isSaving) return false;
    emit(
      state.copyWith(isSaving: true, clearFailure: true, clearFeedback: true),
    );
    final result = id == null
        ? await createTeacher(draft)
        : await updateTeacher(id, draft);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        _fail(failure);
        return false;
      },
      (teacher) {
        final items = [...state.teachers];
        final index = items.indexWhere((item) => item.id == teacher.id);
        index < 0 ? items.add(teacher) : items[index] = teacher;
        items.sort((a, b) => a.fullName.compareTo(b.fullName));
        emit(
          state.copyWith(
            teachers: items,
            isSaving: false,
            feedback: id == null ? 'Учитель добавлен' : 'Учитель обновлён',
            revision: state.revision + 1,
            clearFailure: true,
          ),
        );
        return true;
      },
    );
  }

  Future<void> toggle(ManagedTeacher teacher) async {
    if (state.busyIds.contains(teacher.id)) return;
    _busy(teacher.id);
    final result = await setStatus(teacher.id, !teacher.isActive);
    if (isClosed) return;
    result.fold(
      _fail,
      (updated) => _replace(
        updated,
        updated.isActive ? 'Учитель включён' : 'Учитель отключён',
      ),
    );
  }

  Future<void> delete(ManagedTeacher teacher) async {
    if (state.busyIds.contains(teacher.id)) return;
    _busy(teacher.id);
    final result = await deleteTeacher(teacher.id);
    if (isClosed) return;
    result.fold(
      _fail,
      (_) => emit(
        state.copyWith(
          teachers: state.teachers
              .where((item) => item.id != teacher.id)
              .toList(),
          busyIds: {...state.busyIds}..remove(teacher.id),
          feedback: 'Учитель удалён',
          revision: state.revision + 1,
          clearFailure: true,
        ),
      ),
    );
  }

  Future<TeacherImportSummary?> import(
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
    final result = await importTeachers(text, dryRun: dryRun);
    if (isClosed) return null;
    Failure? failure;
    TeacherImportSummary? summary;
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
    final teachersResult = await getTeachers();
    List<ManagedTeacher>? teachers;
    teachersResult.fold((item) => failure = item, (item) => teachers = item);
    if (failure != null) {
      _fail(failure!);
      emit(state.copyWith(isImporting: false));
      return null;
    }
    emit(
      state.copyWith(
        teachers: teachers,
        isImporting: false,
        feedback: 'Добавлено учителей: ${summary!.createdCount}',
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
  void _replace(ManagedTeacher teacher, String feedback) => emit(
    state.copyWith(
      teachers: state.teachers
          .map((item) => item.id == teacher.id ? teacher : item)
          .toList(),
      busyIds: {...state.busyIds}..remove(teacher.id),
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
