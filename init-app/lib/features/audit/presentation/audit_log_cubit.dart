import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mobile_template/core/errors/failure.dart';
import 'package:mobile_template/features/audit/domain/audit_log_entry.dart';
import 'package:mobile_template/features/audit/domain/audit_log_repository.dart';

class AuditLogState extends Equatable {
  const AuditLogState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.loading = false,
    this.failure,
  });
  final List<AuditLogEntry> items;
  final int total;
  final int page;
  final bool loading;
  final Failure? failure;
  @override
  List<Object?> get props => [items, total, page, loading, failure];
}

@injectable
class AuditLogCubit extends Cubit<AuditLogState> {
  AuditLogCubit(this.repository) : super(const AuditLogState());
  final AuditLogRepository repository;
  bool schoolOnly = false;
  String search = '';
  String method = '';

  Future<void> load({
    bool? schoolScope,
    int page = 1,
    String? query,
    String? methodFilter,
  }) async {
    schoolOnly = schoolScope ?? schoolOnly;
    search = query ?? search;
    method = methodFilter ?? method;
    emit(
      AuditLogState(
        items: state.items,
        total: state.total,
        page: state.page,
        loading: true,
      ),
    );
    final result = await repository.getLogs(
      schoolOnly: schoolOnly,
      page: page,
      search: search,
      method: method,
    );
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        AuditLogState(
          items: state.items,
          total: state.total,
          page: state.page,
          failure: failure,
        ),
      ),
      (data) => emit(
        AuditLogState(items: data.items, total: data.total, page: data.page),
      ),
    );
  }
}
