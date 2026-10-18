import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/features/school_devices/domain/school_devices.dart';

class SchoolDevicesState {
  const SchoolDevicesState({
    this.overview,
    this.invitation,
    this.error,
    this.busy = false,
  });
  final SchoolDeviceOverview? overview;
  final DeviceInvitation? invitation;
  final String? error;
  final bool busy;
}

class SchoolDevicesCubit extends Cubit<SchoolDevicesState> {
  SchoolDevicesCubit(this.actions) : super(const SchoolDevicesState());
  final SchoolDeviceActions actions;
  Future<void> load() async {
    if (state.busy) return;
    emit(SchoolDevicesState(overview: state.overview, busy: true));
    final result = await actions.load();
    if (isClosed) return;
    result.fold(
      (f) =>
          emit(SchoolDevicesState(overview: state.overview, error: f.message)),
      (data) => emit(SchoolDevicesState(overview: data)),
    );
  }

  Future<void> invite(String role) async {
    if (state.busy) return;
    emit(SchoolDevicesState(overview: state.overview, busy: true));
    final result = await actions.invite(role);
    if (isClosed) return;
    result.fold(
      (f) =>
          emit(SchoolDevicesState(overview: state.overview, error: f.message)),
      (data) =>
          emit(SchoolDevicesState(overview: state.overview, invitation: data)),
    );
  }

  void hideInvitation() => emit(SchoolDevicesState(overview: state.overview));
  Future<void> activate(String device) async {
    if (state.busy || state.overview == null) return;
    final generation = state.overview!.generation;
    emit(SchoolDevicesState(overview: state.overview, busy: true));
    final result = await actions.activate(device, generation);
    if (isClosed) return;
    result.fold(
      (f) =>
          emit(SchoolDevicesState(overview: state.overview, error: f.message)),
      (data) => emit(SchoolDevicesState(overview: data)),
    );
  }

  Future<void> revoke(String device) async {
    if (state.busy) return;
    emit(SchoolDevicesState(overview: state.overview, busy: true));
    final result = await actions.revoke(device);
    if (isClosed) return;
    result.fold(
      (f) =>
          emit(SchoolDevicesState(overview: state.overview, error: f.message)),
      (data) => emit(SchoolDevicesState(overview: data)),
    );
  }
}
