import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_guard.dart';
import 'package:mobile_template/features/school_console/domain/usecases/guard_usecases.dart';

enum ManagedGuardsStatus { initial, loading, success, failure }

class SchoolGuardsState extends Equatable {
  const SchoolGuardsState({
    this.status = ManagedGuardsStatus.initial,
    this.guards = const [],
    this.busyIds = const {},
    this.isSaving = false,
    this.revision = 0,
    this.failure,
    this.feedback,
  });
  final ManagedGuardsStatus status;
  final List<ManagedGuard> guards;
  final Set<int> busyIds;
  final bool isSaving;
  final int revision;
  final Failure? failure;
  final String? feedback;
  SchoolGuardsState copyWith({
    ManagedGuardsStatus? status,
    List<ManagedGuard>? guards,
    Set<int>? busyIds,
    bool? isSaving,
    int? revision,
    Failure? failure,
    String? feedback,
    bool clearFailure = false,
    bool clearFeedback = false,
  }) => SchoolGuardsState(
    status: status ?? this.status,
    guards: guards ?? this.guards,
    busyIds: busyIds ?? this.busyIds,
    isSaving: isSaving ?? this.isSaving,
    revision: revision ?? this.revision,
    failure: clearFailure ? null : failure ?? this.failure,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
  );
  @override
  List<Object?> get props => [
    status,
    guards,
    busyIds,
    isSaving,
    revision,
    failure,
    feedback,
  ];
}

@injectable
class SchoolGuardsCubit extends Cubit<SchoolGuardsState> {
  SchoolGuardsCubit(
    this.getGuards,
    this.createGuard,
    this.updateGuard,
    this.setStatus,
    this.deleteGuard,
  ) : super(const SchoolGuardsState());
  final GetManagedGuardsUsecase getGuards;
  final CreateManagedGuardUsecase createGuard;
  final UpdateManagedGuardUsecase updateGuard;
  final SetManagedGuardStatusUsecase setStatus;
  final DeleteManagedGuardUsecase deleteGuard;
  Future<void> load() async {
    emit(
      state.copyWith(status: ManagedGuardsStatus.loading, clearFailure: true),
    );
    final result = await getGuards();
    if (isClosed) return;
    result.fold(
      (f) =>
          emit(state.copyWith(status: ManagedGuardsStatus.failure, failure: f)),
      (items) => emit(
        state.copyWith(
          status: ManagedGuardsStatus.success,
          guards: items,
          clearFailure: true,
        ),
      ),
    );
  }

  Future<bool> save({int? id, required GuardDraft draft}) async {
    if (state.isSaving) return false;
    emit(
      state.copyWith(isSaving: true, clearFailure: true, clearFeedback: true),
    );
    final result = id == null
        ? await createGuard(draft)
        : await updateGuard(id, draft);
    if (isClosed) return false;
    return result.fold(
      (f) {
        _fail(f);
        return false;
      },
      (guard) {
        final items = [...state.guards];
        final index = items.indexWhere((e) => e.id == guard.id);
        index < 0 ? items.add(guard) : items[index] = guard;
        items.sort((a, b) => a.fullName.compareTo(b.fullName));
        emit(
          state.copyWith(
            guards: items,
            isSaving: false,
            feedback: id == null ? 'Охранник добавлен' : 'Охранник обновлён',
            revision: state.revision + 1,
            clearFailure: true,
          ),
        );
        return true;
      },
    );
  }

  Future<void> toggle(ManagedGuard guard) async {
    if (state.busyIds.contains(guard.id)) return;
    _busy(guard.id);
    final result = await setStatus(guard.id, !guard.isActive);
    if (isClosed) return;
    result.fold(
      _fail,
      (updated) => _replace(
        updated,
        updated.isActive ? 'Охранник включён' : 'Охранник отключён',
      ),
    );
  }

  Future<void> delete(ManagedGuard guard) async {
    if (state.busyIds.contains(guard.id)) return;
    _busy(guard.id);
    final result = await deleteGuard(guard.id);
    if (isClosed) return;
    result.fold(
      _fail,
      (_) => emit(
        state.copyWith(
          guards: state.guards.where((e) => e.id != guard.id).toList(),
          busyIds: {...state.busyIds}..remove(guard.id),
          feedback: 'Охранник удалён',
          revision: state.revision + 1,
          clearFailure: true,
        ),
      ),
    );
  }

  void _busy(int id) => emit(
    state.copyWith(
      busyIds: {...state.busyIds, id},
      clearFailure: true,
      clearFeedback: true,
    ),
  );
  void _replace(ManagedGuard guard, String message) => emit(
    state.copyWith(
      guards: state.guards.map((e) => e.id == guard.id ? guard : e).toList(),
      busyIds: {...state.busyIds}..remove(guard.id),
      feedback: message,
      revision: state.revision + 1,
      clearFailure: true,
    ),
  );
  void _fail(Failure f) => emit(
    state.copyWith(
      isSaving: false,
      busyIds: const {},
      failure: f,
      feedback: f.message.isEmpty ? 'Не удалось выполнить действие' : f.message,
      revision: state.revision + 1,
    ),
  );
}
