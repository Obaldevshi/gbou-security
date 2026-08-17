import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_school_building.dart';
import 'package:mobile_template/features/school_console/domain/usecases/school_building_usecases.dart';

enum ManagedBuildingsStatus { initial, loading, success, failure }

class SchoolBuildingsState extends Equatable {
  const SchoolBuildingsState({
    this.status = ManagedBuildingsStatus.initial,
    this.buildings = const [],
    this.busyIds = const {},
    this.isSaving = false,
    this.revision = 0,
    this.failure,
    this.feedback,
  });
  final ManagedBuildingsStatus status;
  final List<ManagedSchoolBuilding> buildings;
  final Set<int> busyIds;
  final bool isSaving;
  final int revision;
  final Failure? failure;
  final String? feedback;

  SchoolBuildingsState copyWith({
    ManagedBuildingsStatus? status,
    List<ManagedSchoolBuilding>? buildings,
    Set<int>? busyIds,
    bool? isSaving,
    int? revision,
    Failure? failure,
    String? feedback,
    bool clearFailure = false,
    bool clearFeedback = false,
  }) => SchoolBuildingsState(
    status: status ?? this.status,
    buildings: buildings ?? this.buildings,
    busyIds: busyIds ?? this.busyIds,
    isSaving: isSaving ?? this.isSaving,
    revision: revision ?? this.revision,
    failure: clearFailure ? null : failure ?? this.failure,
    feedback: clearFeedback ? null : feedback ?? this.feedback,
  );

  @override
  List<Object?> get props => [
    status,
    buildings,
    busyIds,
    isSaving,
    revision,
    failure,
    feedback,
  ];
}

class SchoolBuildingsCubit extends Cubit<SchoolBuildingsState> {
  SchoolBuildingsCubit(
    this.getItems,
    this.saveItem,
    this.setStatus,
    this.deleteItem,
  ) : super(const SchoolBuildingsState());

  final GetManagedBuildingsUsecase getItems;
  final SaveManagedBuildingUsecase saveItem;
  final SetManagedBuildingStatusUsecase setStatus;
  final DeleteManagedBuildingUsecase deleteItem;

  Future<void> load() async {
    emit(
      state.copyWith(
        status: ManagedBuildingsStatus.loading,
        clearFailure: true,
      ),
    );
    final result = await getItems();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ManagedBuildingsStatus.failure,
          failure: failure,
        ),
      ),
      (items) => emit(
        state.copyWith(
          status: ManagedBuildingsStatus.success,
          buildings: items,
          clearFailure: true,
        ),
      ),
    );
  }

  Future<bool> save({
    int? id,
    required String name,
    required String address,
  }) async {
    if (state.isSaving) return false;
    emit(
      state.copyWith(isSaving: true, clearFailure: true, clearFeedback: true),
    );
    final result = await saveItem(id: id, name: name, address: address);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        _fail(failure);
        return false;
      },
      (item) {
        final items = [...state.buildings];
        final index = items.indexWhere((value) => value.id == item.id);
        index < 0 ? items.add(item) : items[index] = item;
        items.sort((a, b) => a.name.compareTo(b.name));
        emit(
          state.copyWith(
            buildings: items,
            isSaving: false,
            revision: state.revision + 1,
            feedback: id == null ? 'Корпус добавлен' : 'Корпус обновлён',
            clearFailure: true,
          ),
        );
        return true;
      },
    );
  }

  Future<void> toggle(ManagedSchoolBuilding item) async {
    _busy(item.id);
    final result = await setStatus(item.id, !item.isActive);
    if (isClosed) return;
    result.fold(
      _fail,
      (updated) => _replace(
        updated,
        updated.isActive ? 'Корпус включён' : 'Корпус отключён',
      ),
    );
  }

  Future<void> delete(ManagedSchoolBuilding item) async {
    _busy(item.id);
    final result = await deleteItem(item.id);
    if (isClosed) return;
    result.fold(
      _fail,
      (_) => emit(
        state.copyWith(
          buildings: state.buildings
              .where((value) => value.id != item.id)
              .toList(),
          busyIds: {...state.busyIds}..remove(item.id),
          revision: state.revision + 1,
          feedback: 'Корпус удалён',
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

  void _replace(ManagedSchoolBuilding item, String message) => emit(
    state.copyWith(
      buildings: state.buildings
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
