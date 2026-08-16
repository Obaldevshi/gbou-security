import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/data/models/response/profile_response.dart';
import 'package:mobile_template/features/profile/domain/dto/profile_dto.dart';

void main() {
  test('maps role-aware profile returned by the API', () {
    final response = ProfileResponse.fromJson({
      'id': 7,
      'login': 'school.admin',
      'full_name': 'Администратор школы',
      'phone': '+79990000000',
      'role': 'school_admin',
      'school_id': 3,
      'is_active': true,
      'created_at': '2026-08-10T12:00:00',
      'updated_at': '2026-08-16T12:00:00',
    });

    final profile = ProfileDto.fromResponse(response);

    expect(profile.login, 'school.admin');
    expect(profile.fullName, 'Администратор школы');
    expect(profile.role, 'school_admin');
    expect(profile.schoolId, 3);
  });
}
