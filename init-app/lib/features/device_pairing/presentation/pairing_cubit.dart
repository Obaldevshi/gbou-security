import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing.dart';

class PairingState {
  const PairingState({
    this.session,
    this.schools = const [],
    this.schoolId,
    this.school,
    this.preview,
    this.busy = false,
    this.error,
    this.done = false,
  });
  final PairingSession? session;
  final List<PairingChoice> schools;
  final int? schoolId;
  final PairingSchool? school;
  final PairingPreview? preview;
  final bool busy, done;
  final String? error;
}

class PairingCubit extends Cubit<PairingState> {
  PairingCubit(this.actions, this.requestId) : super(const PairingState());
  final PairingActions actions;
  final String? requestId;
  bool get _valid =>
      state.session != null &&
      DateTime.now().isBefore(state.session!.expiresAt);
  void logout() => emit(const PairingState());
  void _error(Failure failure) {
    if (isClosed) return;
    if (failure.errorCode == 'pairing_session_expired' || !_valid) {
      emit(PairingState(error: failure.message));
    } else {
      emit(
        PairingState(
          session: state.session,
          schools: state.schools,
          schoolId: state.schoolId,
          school: state.school,
          preview: state.preview,
          error: failure.message,
        ),
      );
    }
  }

  Future<void> login(String login, String password) async {
    if (state.busy) return;
    emit(const PairingState(busy: true));
    final result = await actions.login(login, password);
    if (isClosed) return;
    await result.fold((f) async => _error(f), (session) async {
      await _loadSession(session);
    });
  }

  Future<void> changePassword(String password) async {
    if (state.busy || !_valid) return;
    final session = state.session!;
    emit(PairingState(session: session, busy: true));
    final result = await actions.changePassword(session.token, password);
    if (isClosed) return;
    await result.fold((f) async => _error(f), _loadSession);
  }

  Future<void> _loadSession(PairingSession session) async {
    emit(PairingState(session: session, busy: !session.passwordChangeRequired));
    if (session.passwordChangeRequired) return;
    final schools = await actions.schools(session.token);
    if (isClosed) return;
    await schools.fold((f) async => _error(f), (choices) async {
      emit(PairingState(session: session, schools: choices));
      if (requestId != null) {
        final preview = await actions.inspect(session.token, requestId!);
        if (isClosed) return;
        preview.fold(
          _error,
          (data) => emit(
            PairingState(session: session, schools: choices, preview: data),
          ),
        );
        if (state.error != null) return;
      }
      if (choices.length == 1 && state.session != null) {
        await selectSchool(choices.single.id);
      }
    });
  }

  Future<void> selectSchool(int id) async {
    if (state.busy) return;
    if (!_valid) {
      logout();
      return;
    }
    final session = state.session!;
    final preview = state.preview;
    emit(
      PairingState(
        session: session,
        schools: state.schools,
        schoolId: id,
        preview: preview,
        busy: true,
      ),
    );
    final result = await actions.school(session.token, id);
    if (isClosed) return;
    result.fold(
      _error,
      (data) => emit(
        PairingState(
          session: session,
          schools: state.schools,
          schoolId: id,
          school: data,
          preview: preview,
        ),
      ),
    );
  }

  Future<void> _change(
    Future<Either<Failure, PairingSchool>> Function(String token, int school)
    action, {
    bool approved = false,
  }) async {
    if (state.busy || state.schoolId == null || !_valid) {
      if (!_valid) logout();
      return;
    }
    final old = state;
    emit(
      PairingState(
        session: old.session,
        schools: old.schools,
        schoolId: old.schoolId,
        school: old.school,
        preview: old.preview,
        busy: true,
      ),
    );
    final result = await action(old.session!.token, old.schoolId!);
    if (isClosed) return;
    result.fold(
      _error,
      (data) => emit(
        PairingState(
          session: old.session,
          schools: old.schools,
          schoolId: old.schoolId,
          school: data,
          preview: approved ? null : old.preview,
          done: approved,
        ),
      ),
    );
  }

  Future<void> approve(int building, String role, String code) async {
    if (requestId == null || state.preview == null) return;
    await _change(
      (token, school) =>
          actions.approve(token, requestId!, school, building, role, code),
      approved: true,
    );
  }

  Future<void> activate(String device) async {
    final generation = state.school?.generation;
    if (generation != null) {
      await _change(
        (token, school) => actions.activate(token, school, device, generation),
      );
    }
  }

  Future<void> revoke(String device) =>
      _change((token, school) => actions.revoke(token, school, device));
}
