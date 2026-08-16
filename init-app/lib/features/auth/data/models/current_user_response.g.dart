// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_user_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CurrentUserResponse _$CurrentUserResponseFromJson(Map<String, dynamic> json) =>
    CurrentUserResponse(
      id: (json['id'] as num).toInt(),
      login: json['login'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      phone: json['phone'] as String?,
      schoolId: (json['school_id'] as num?)?.toInt(),
    );
