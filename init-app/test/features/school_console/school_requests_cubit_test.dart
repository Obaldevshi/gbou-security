import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/exit_requests/data/repositories/mock_exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_school_exit_requests_usecase.dart';
import 'package:mobile_template/features/school_console/presentation/school_requests_cubit.dart';

void main() {
  test('loads school request snapshot', () async {
    final cubit = SchoolRequestsCubit(
      GetSchoolExitRequestsUsecase(MockExitRequestRepository()),
    );
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.status, SchoolRequestsStatus.success);
    expect(cubit.state.active, isEmpty);
    expect(cubit.state.history, isEmpty);
  });
}
