import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/school_management/domain/entities/school.dart';
import 'package:mobile_template/features/school_management/domain/usecases/school_usecases.dart';

import 'school_management_state.dart';

@injectable
class SchoolManagementCubit extends Cubit<SchoolManagementState> {
  SchoolManagementCubit(
    this._getSchools,
    this._getStats,
    this._createSchool,
    this._updateSchool,
    this._setStatus,
    this._deleteSchool,
  ) : super(const SchoolManagementState());

  final GetSchoolsUsecase _getSchools;
  final GetSystemStatsUsecase _getStats;
  final CreateSchoolUsecase _createSchool;
  final UpdateSchoolUsecase _updateSchool;
  final SetSchoolStatusUsecase _setStatus;
  final DeleteSchoolUsecase _deleteSchool;

  Future<void> load() async {
    emit(
      state.copyWith(
        status: SchoolManagementStatus.loading,
        clearFailure: true,
      ),
    );
    final result = await _getSchools();
    final statsResult = await _getStats();
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SchoolManagementStatus.failure,
          failure: failure,
        ),
      ),
      (schools) => statsResult.fold(
        (failure) => emit(
          state.copyWith(
            status: SchoolManagementStatus.failure,
            failure: failure,
          ),
        ),
        (stats) => emit(
          state.copyWith(
            status: SchoolManagementStatus.success,
            schools: schools,
            stats: stats,
            clearFailure: true,
          ),
        ),
      ),
    );
  }

  Future<bool> save({int? id, required SchoolDraft draft}) async {
    if (state.isSaving) return false;
    emit(
      state.copyWith(isSaving: true, clearFailure: true, clearFeedback: true),
    );
    final result = id == null
        ? await _createSchool(draft)
        : await _updateSchool(id, draft);
    if (isClosed) return false;
    return result.fold(
      (failure) {
        _emitFailure(failure);
        return false;
      },
      (school) {
        final schools = [...state.schools];
        final index = schools.indexWhere((item) => item.id == school.id);
        if (index == -1) {
          schools.add(school);
        } else {
          schools[index] = school;
        }
        schools.sort((a, b) => a.shortName.compareTo(b.shortName));
        emit(
          state.copyWith(
            schools: schools,
            isSaving: false,
            feedback: id == null ? 'Школа создана' : 'Школа обновлена',
            feedbackRevision: state.feedbackRevision + 1,
            clearFailure: true,
          ),
        );
        return true;
      },
    );
  }

  Future<void> toggleStatus(School school) async {
    if (state.busyIds.contains(school.id)) return;
    _setBusy(school.id, true);
    final result = await _setStatus(school.id, !school.isActive);
    if (isClosed) return;
    result.fold(_emitFailure, (updated) {
      _replace(
        updated,
        feedback: updated.isActive ? 'Школа включена' : 'Школа отключена',
      );
    });
  }

  Future<void> delete(School school) async {
    if (state.busyIds.contains(school.id)) return;
    _setBusy(school.id, true);
    final result = await _deleteSchool(school.id);
    if (isClosed) return;
    result.fold(_emitFailure, (_) {
      emit(
        state.copyWith(
          schools: state.schools.where((item) => item.id != school.id).toList(),
          busyIds: {...state.busyIds}..remove(school.id),
          feedback: 'Школа и все связанные данные удалены',
          feedbackRevision: state.feedbackRevision + 1,
          clearFailure: true,
        ),
      );
    });
  }

  void _replace(School school, {required String feedback}) {
    emit(
      state.copyWith(
        schools: state.schools
            .map((item) => item.id == school.id ? school : item)
            .toList(),
        busyIds: {...state.busyIds}..remove(school.id),
        feedback: feedback,
        feedbackRevision: state.feedbackRevision + 1,
        clearFailure: true,
      ),
    );
  }

  void _setBusy(int id, bool value) {
    final ids = {...state.busyIds};
    value ? ids.add(id) : ids.remove(id);
    emit(state.copyWith(busyIds: ids, clearFailure: true, clearFeedback: true));
  }

  void _emitFailure(Failure failure) => emit(
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
