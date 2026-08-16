import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/auth/data/models/current_user_response.dart';

void main() {
  test('maps mandatory password change from API', () {
    final response = CurrentUserResponse.fromJson({
      'id': 1,
      'login': 'teacher.demo',
      'full_name': 'Учитель',
      'phone': null,
      'role': 'teacher',
      'school_id': 2,
      'is_active': true,
      'must_change_password': true,
    });

    expect(response.toDomain().mustChangePassword, isTrue);
  });
}
