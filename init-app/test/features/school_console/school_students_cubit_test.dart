import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/school_console/data/mock_school_classes_repository.dart';
import 'package:mobile_template/features/school_console/data/mock_school_students_repository.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/usecases/school_class_usecases.dart';
import 'package:mobile_template/features/school_console/domain/usecases/student_usecases.dart';
import 'package:mobile_template/features/school_console/presentation/school_students_cubit.dart';

void main() {
  test('loads classes and students, then creates a student', () async {
    final classes = MockSchoolClassesRepository();
    final students = MockSchoolStudentsRepository();
    final cubit = SchoolStudentsCubit(
      GetManagedClassesUsecase(classes),
      GetManagedStudentsUsecase(students),
      CreateManagedStudentUsecase(students),
      UpdateManagedStudentUsecase(students),
      SetManagedStudentStatusUsecase(students),
      DeleteManagedStudentUsecase(students),
    );
    addTearDown(cubit.close);

    await cubit.load();
    final saved = await cubit.save(
      draft: const StudentDraft(
        classId: 1,
        lastName: 'Петров',
        firstName: 'Пётр',
      ),
    );

    expect(saved, isTrue);
    expect(cubit.state.status, ManagedStudentsStatus.success);
    expect(cubit.state.classes, hasLength(2));
    expect(cubit.state.students, hasLength(2));
    expect(cubit.state.feedback, 'Ученик добавлен');
  });

  test('filters students by class', () async {
    final classes = MockSchoolClassesRepository();
    final students = MockSchoolStudentsRepository();
    final cubit = SchoolStudentsCubit(
      GetManagedClassesUsecase(classes),
      GetManagedStudentsUsecase(students),
      CreateManagedStudentUsecase(students),
      UpdateManagedStudentUsecase(students),
      SetManagedStudentStatusUsecase(students),
      DeleteManagedStudentUsecase(students),
    );
    addTearDown(cubit.close);

    await cubit.load(classId: 2);

    expect(cubit.state.classFilter, 2);
    expect(cubit.state.students, isEmpty);
  });
}
