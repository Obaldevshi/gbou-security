import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_classes_usecase.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/usecases/teacher_student_usecases.dart';

enum TeacherStudentsStatus { initial, loading, success, failure }

class TeacherStudentsState extends Equatable {
  const TeacherStudentsState({
    this.status = TeacherStudentsStatus.initial,
    this.classes = const [],
    this.students = const [],
    this.busyIds = const {},
    this.saving = false,
    this.revision = 0,
    this.failure,
    this.feedback,
  });
  final TeacherStudentsStatus status;
  final List<TeacherClass> classes;
  final List<ManagedStudent> students;
  final Set<int> busyIds;
  final bool saving;
  final int revision;
  final Failure? failure;
  final String? feedback;
  @override
  List<Object?> get props => [
    status,
    classes,
    students,
    busyIds,
    saving,
    revision,
    failure,
    feedback,
  ];
}

@injectable
class TeacherStudentsCubit extends Cubit<TeacherStudentsState> {
  TeacherStudentsCubit(
    this.getClasses,
    this.getStudents,
    this.createStudent,
    this.setStatus,
    this.deleteStudent,
  ) : super(const TeacherStudentsState());
  final GetTeacherClassesUsecase getClasses;
  final GetTeacherStudentsUsecase getStudents;
  final CreateTeacherStudentUsecase createStudent;
  final SetTeacherStudentStatusUsecase setStatus;
  final DeleteTeacherStudentUsecase deleteStudent;
  Future<void> load() async {
    emit(const TeacherStudentsState(status: TeacherStudentsStatus.loading));
    final cr = await getClasses();
    final sr = await getStudents();
    if (isClosed) return;
    Failure? f;
    List<TeacherClass>? c;
    List<ManagedStudent>? s;
    cr.fold((e) => f = e, (e) => c = e);
    sr.fold((e) => f ??= e, (e) => s = e);
    emit(
      f == null
          ? TeacherStudentsState(
              status: TeacherStudentsStatus.success,
              classes: c!,
              students: s!,
            )
          : TeacherStudentsState(
              status: TeacherStudentsStatus.failure,
              failure: f,
            ),
    );
  }

  Future<bool> create(StudentDraft d) async {
    if (state.saving) return false;
    emit(_copy(saving: true));
    final r = await createStudent(d);
    if (isClosed) return false;
    return r.fold(
      (f) {
        _fail(f);
        return false;
      },
      (e) {
        emit(
          _copy(
            students: [...state.students, e],
            saving: false,
            feedback: 'Ученик добавлен',
            revision: state.revision + 1,
          ),
        );
        return true;
      },
    );
  }

  Future<void> toggle(ManagedStudent e) async {
    if (state.busyIds.contains(e.id)) return;
    emit(_copy(busyIds: {...state.busyIds, e.id}));
    final r = await setStatus(e.id, !e.isActive);
    if (isClosed) return;
    r.fold(
      _fail,
      (u) => emit(
        _copy(
          students: state.students.map((x) => x.id == u.id ? u : x).toList(),
          busyIds: {...state.busyIds}..remove(e.id),
          feedback: u.isActive ? 'Ученик включён' : 'Ученик отключён',
          revision: state.revision + 1,
        ),
      ),
    );
  }

  Future<void> delete(ManagedStudent e) async {
    if (state.busyIds.contains(e.id)) return;
    emit(_copy(busyIds: {...state.busyIds, e.id}));
    final r = await deleteStudent(e.id);
    if (isClosed) return;
    r.fold(
      _fail,
      (_) => emit(
        _copy(
          students: state.students.where((x) => x.id != e.id).toList(),
          busyIds: {...state.busyIds}..remove(e.id),
          feedback: 'Ученик удалён',
          revision: state.revision + 1,
        ),
      ),
    );
  }

  TeacherStudentsState _copy({
    TeacherStudentsStatus? status,
    List<TeacherClass>? classes,
    List<ManagedStudent>? students,
    Set<int>? busyIds,
    bool? saving,
    int? revision,
    Failure? failure,
    String? feedback,
  }) => TeacherStudentsState(
    status: status ?? state.status,
    classes: classes ?? state.classes,
    students: students ?? state.students,
    busyIds: busyIds ?? state.busyIds,
    saving: saving ?? state.saving,
    revision: revision ?? state.revision,
    failure: failure,
    feedback: feedback,
  );
  void _fail(Failure f) => emit(
    _copy(
      busyIds: const {},
      saving: false,
      failure: f,
      feedback: f.message.isEmpty ? 'Не удалось выполнить действие' : f.message,
      revision: state.revision + 1,
    ),
  );
}
