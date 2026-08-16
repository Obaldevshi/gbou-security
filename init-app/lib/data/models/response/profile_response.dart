import 'package:json_annotation/json_annotation.dart';

part 'profile_response.g.dart';

@JsonSerializable(createToJson: false)
class ProfileResponse {
  const ProfileResponse({
    required this.id,
    required this.login,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.schoolId,
  });

  final int id;
  final String login;
  @JsonKey(name: 'full_name')
  final String fullName;
  final String? phone;
  final String role;
  @JsonKey(name: 'school_id')
  final int? schoolId;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  factory ProfileResponse.fromJson(Map<String, dynamic> json) =>
      _$ProfileResponseFromJson(json);
}
