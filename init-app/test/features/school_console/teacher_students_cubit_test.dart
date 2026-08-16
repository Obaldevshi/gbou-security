import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/exit_requests/data/repositories/mock_exit_request_repository.dart';
import 'package:mobile_template/features/exit_requests/domain/usecases/get_teacher_classes_usecase.dart';
import 'package:mobile_template/features/school_console/data/mock_teacher_students_repository.dart';
import 'package:mobile_template/features/school_console/domain/entities/managed_student.dart';
import 'package:mobile_template/features/school_console/domain/usecases/teacher_student_usecases.dart';
import 'package:mobile_template/features/school_console/presentation/teacher_students_cubit.dart';

void main() {
  test('loads and adds assigned student', () async {
    final students = MockTeacherStudentsRepository();
    final cubit = TeacherStudentsCubit(
      GetTeacherClassesUsecase(MockExitRequestRepository()),
      GetTeacherStudentsUsecase(students),
      CreateTeacherStudentUsecase(students),
      SetTeacherStudentStatusUsecase(students),
      DeleteTeacherStudentUsecase(students),
    );
    addTearDown(cubit.close);
    await cubit.load();
    final ok = await cubit.create(
      const StudentDraft(classId: 1, lastName: 'Петров', firstName: 'Пётр'),
    );
    expect(ok, isTrue);
    expect(cubit.state.students, hasLength(2));
  });
}
