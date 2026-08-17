import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/school_console/data/mock_school_guards_repository.dart';
import 'package:mobile_template/features/school_console/data/mock_school_buildings_repository.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_guard.dart';
import 'package:mobile_template/features/school_console/domain/usecases/guard_usecases.dart';
import 'package:mobile_template/features/school_console/domain/usecases/school_building_usecases.dart';
import 'package:mobile_template/features/school_console/presentation/school_guards_cubit.dart';

void main() {
  test('loads and creates a guard', () async {
    final repository = MockSchoolGuardsRepository();
    final buildings = MockSchoolBuildingsRepository();
    final cubit = SchoolGuardsCubit(
      GetManagedBuildingsUsecase(buildings),
      GetManagedGuardsUsecase(repository),
      CreateManagedGuardUsecase(repository),
      UpdateManagedGuardUsecase(repository),
      SetManagedGuardStatusUsecase(repository),
      DeleteManagedGuardUsecase(repository),
    );
    addTearDown(cubit.close);
    await cubit.load();
    final saved = await cubit.save(
      draft: const GuardDraft(
        login: 'guard.two',
        fullName: 'Пост №2',
        buildingId: 1,
        password: 'StrongPass123!',
      ),
    );
    expect(saved, isTrue);
    expect(cubit.state.status, ManagedGuardsStatus.success);
    expect(cubit.state.guards, hasLength(2));
    expect(cubit.state.feedback, 'Охранник добавлен');
  });
}
