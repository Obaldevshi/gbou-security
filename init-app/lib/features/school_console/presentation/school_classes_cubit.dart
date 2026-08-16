import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_class.dart';
import 'package:mobile_template/features/school_console/domain/usecases/school_class_usecases.dart';

enum ManagedClassesStatus { initial, loading, success, failure }

class SchoolClassesState extends Equatable {
  const SchoolClassesState({
    this.status = ManagedClassesStatus.initial,
    this.classes = const [],
    this.busyIds = const {},
    this.isSaving = false,
    this.revision = 0,
    this.failure,
    this.feedback,
  });
  final ManagedClassesStatus status;
  final List<ManagedSchoolClass> classes;
  final Set<int> busyIds;
  final bool isSaving;
  final int revision;
  final Failure? failure;
  final String? feedback;
  SchoolClassesState copyWith({
    ManagedClassesStatus? status,
    List<ManagedSchoolClass>? classes,
    Set<int>? busyIds,
    bool? isSaving,
    int? revision,
    Failure? failure,
    String? feedback,
    bool clearFailure = false,
    bool clearFeedback = false,
  }) => SchoolClassesState(
    status: status ?? this.status,
    classes: classes ?? this.classes,
    busyIds: busyIds ?? this.busyIds,
    isSaving: isSaving ?? this.isSaving,
    revision: revision ?? this.revision,
    failure: clearFailure ? null : failure ?? this.failure,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
  );
  @override
  List<Object?> get props => [
    status,
    classes,
    busyIds,
    isSaving,
    revision,
    failure,
    feedback,
  ];
}

@injectable
class SchoolClassesCubit extends Cubit<SchoolClassesState> {
  SchoolClassesCubit(
    this.getClasses,
    this.createClass,
    this.updateClass,
    this.setStatus,
    this.deleteClass,
  ) : super(const SchoolClassesState());
  final GetManagedClassesUsecase getClasses;
  final CreateManagedClassUsecase createClass;
  final UpdateManagedClassUsecase updateClass;
  final SetManagedClassStatusUsecase setStatus;
  final DeleteManagedClassUsecase deleteClass;
  Future<void> load() async {
    emit(
      state.copyWith(status: ManagedClassesStatus.loading, clearFailure: true),
    );
    final result = await getClasses();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(status: ManagedClassesStatus.failure, failure: failure),
      ),
      (items) => emit(
        state.copyWith(
          status: ManagedClassesStatus.success,
          classes: items,
          clearFailure: true,
        ),
      ),
    );
  }

  Future<bool> save({int? id, required String name}) async {
    if (state.isSaving) return false;
    emit(
      state.copyWith(isSaving: true, clearFailure: true, clearFeedback: true),
    );
    final result = id == null
        ? await createClass(name)
        : await updateClass(id, name);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        _fail(failure);
        return false;
      },
      (item) {
        final items = [...state.classes];
        final index = items.indexWhere((value) => value.id == item.id);
        index < 0 ? items.add(item) : items[index] = item;
        items.sort((a, b) => a.name.compareTo(b.name));
        emit(
          state.copyWith(
            classes: items,
            isSaving: false,
            revision: state.revision + 1,
            feedback: id == null ? 'Класс создан' : 'Класс обновлён',
            clearFailure: true,
          ),
        );
        return true;
      },
    );
  }

  Future<void> toggle(ManagedSchoolClass item) async {
    if (state.busyIds.contains(item.id)) return;
    _busy(item.id);
    final result = await setStatus(item.id, !item.isActive);
    if (isClosed) return;
    result.fold(
      _fail,
      (updated) => _replace(
        updated,
        updated.isActive ? 'Класс включён' : 'Класс отключён',
      ),
    );
  }

  Future<void> delete(ManagedSchoolClass item) async {
    if (state.busyIds.contains(item.id)) return;
    _busy(item.id);
    final result = await deleteClass(item.id);
    if (isClosed) return;
    result.fold(
      _fail,
      (_) => emit(
        state.copyWith(
          classes: state.classes.where((value) => value.id != item.id).toList(),
          busyIds: {...state.busyIds}..remove(item.id),
          revision: state.revision + 1,
          feedback: 'Класс удалён',
          clearFailure: true,
        ),
      ),
    );
  }

  void _busy(int id) => emit(
    state.copyWith(
      busyIds: {...state.busyIds, id},
      clearFeedback: true,
      clearFailure: true,
    ),
  );
  void _replace(ManagedSchoolClass item, String message) => emit(
    state.copyWith(
      classes: state.classes
          .map((value) => value.id == item.id ? item : value)
          .toList(),
      busyIds: {...state.busyIds}..remove(item.id),
      revision: state.revision + 1,
      feedback: message,
      clearFailure: true,
    ),
  );
  void _fail(Failure failure) => emit(
    state.copyWith(
      isSaving: false,
      busyIds: const {},
      failure: failure,
      feedback: failure.message.isEmpty
          ? 'Не удалось выполнить действие'
          : failure.message,
      revision: state.revision + 1,
    ),
  );
}
