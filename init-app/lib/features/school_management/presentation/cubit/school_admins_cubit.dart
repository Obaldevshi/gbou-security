import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';
import 'package:mobile_template/features/school_management/domain/usecases/school_usecases.dart';

import 'school_admins_state.dart';

@injectable
class SchoolAdminsCubit extends Cubit<SchoolAdminsState> {
  SchoolAdminsCubit(
    this._getSchools,
    this._getAdmins,
    this._create,
    this._update,
    this._setStatus,
    this._delete,
  ) : super(const SchoolAdminsState());
  final GetSchoolsUsecase _getSchools;
  final GetSchoolAdminsUsecase _getAdmins;
  final CreateSchoolAdminUsecase _create;
  final UpdateSchoolAdminUsecase _update;
  final SetSchoolAdminStatusUsecase _setStatus;
  final DeleteSchoolAdminUsecase _delete;

  Future<void> load() async {
    emit(
      state.copyWith(status: SchoolAdminsStatus.loading, clearFailure: true),
    );
    final schoolsResult = await _getSchools();
    final adminsResult = await _getAdmins();
    if (isClosed) return;
    Failure? failure;
    List<School>? schools;
    List<SchoolAdmin>? admins;
    schoolsResult.fold((value) => failure = value, (value) => schools = value);
    adminsResult.fold((value) => failure ??= value, (value) => admins = value);
    if (failure != null) {
      emit(
        state.copyWith(status: SchoolAdminsStatus.failure, failure: failure),
      );
    } else {
      emit(
        state.copyWith(
          status: SchoolAdminsStatus.success,
          schools: schools,
          admins: admins,
          clearFailure: true,
        ),
      );
    }
  }

  Future<bool> save({int? id, required SchoolAdminDraft draft}) async {
    if (state.isSaving) return false;
    emit(
      state.copyWith(isSaving: true, clearFailure: true, clearFeedback: true),
    );
    final result = id == null ? await _create(draft) : await _update(id, draft);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        _failure(failure);
        return false;
      },
      (admin) {
        final admins = [...state.admins];
        final index = admins.indexWhere((item) => item.id == admin.id);
        index < 0 ? admins.add(admin) : admins[index] = admin;
        admins.sort((a, b) => a.fullName.compareTo(b.fullName));
        emit(
          state.copyWith(
            admins: admins,
            isSaving: false,
            feedback: id == null
                ? 'Администратор создан'
                : 'Администратор обновлён',
            feedbackRevision: state.feedbackRevision + 1,
            clearFailure: true,
          ),
        );
        return true;
      },
    );
  }

  Future<void> toggle(SchoolAdmin admin) async {
    if (state.busyIds.contains(admin.id)) return;
    _busy(admin.id);
    final result = await _setStatus(admin.id, !admin.isActive);
    if (isClosed) return;
    result.fold(
      _failure,
      (updated) => _replace(
        updated,
        updated.isActive
            ? 'Учётная запись включена'
            : 'Учётная запись отключена',
      ),
    );
  }

  Future<void> delete(SchoolAdmin admin) async {
    if (state.busyIds.contains(admin.id)) return;
    _busy(admin.id);
    final result = await _delete(admin.id);
    if (isClosed) return;
    result.fold(
      _failure,
      (_) => emit(
        state.copyWith(
          admins: state.admins.where((item) => item.id != admin.id).toList(),
          busyIds: {...state.busyIds}..remove(admin.id),
          feedback: 'Администратор удалён',
          feedbackRevision: state.feedbackRevision + 1,
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
  void _replace(SchoolAdmin admin, String message) => emit(
    state.copyWith(
      admins: state.admins
          .map((item) => item.id == admin.id ? admin : item)
          .toList(),
      busyIds: {...state.busyIds}..remove(admin.id),
      feedback: message,
      feedbackRevision: state.feedbackRevision + 1,
      clearFailure: true,
    ),
  );
  void _failure(Failure failure) => emit(
    state.copyWith(
      isSaving: false,
      busyIds: const {},
      failure: failure,
      feedback: failure.message.isEmpty
          ? 'Не удалось выполнить действие'
          : failure.message,
      feedbackRevision: state.feedbackRevision + 1,
    ),
  );
}
