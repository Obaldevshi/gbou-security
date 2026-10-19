import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/account_deletion/domain/account_deletion.dart';

class AccountDeletionState {
  const AccountDeletionState({
    this.info,
    this.loading = false,
    this.deleting = false,
    this.deleted = false,
    this.failure,
  });
  final AccountDeletionInfo? info;
  final bool loading, deleting, deleted;
  final Failure? failure;
}

class AccountDeletionCubit extends Cubit<AccountDeletionState> {
  AccountDeletionCubit(this.repository) : super(const AccountDeletionState());
  final AccountDeletionRepository repository;
  Future<void> load() async {
    emit(const AccountDeletionState(loading: true));
    final result = await repository.info();
    if (isClosed) return;
    result.fold(
      (error) => emit(AccountDeletionState(failure: error)),
      (info) => emit(AccountDeletionState(info: info)),
    );
  }

  Future<void> delete(String password, String confirmation) async {
    if (state.deleting || state.info?.canDelete != true) return;
    emit(AccountDeletionState(info: state.info, deleting: true));
    final result = await DeleteOwnAccount(repository)(password, confirmation);
    if (isClosed) return;
    result.fold(
      (error) => emit(AccountDeletionState(info: state.info, failure: error)),
      (_) => emit(AccountDeletionState(info: state.info, deleted: true)),
    );
  }
}
