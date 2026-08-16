import 'package:mobile_template/features/exit_requests/domain/entities/exit_request.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/student.dart';
import 'package:mobile_template/features/exit_requests/domain/entities/teacher_class.dart';

class TeacherClassResponse {
  const TeacherClassResponse({required this.id, required this.name});

  final int id;
  final String name;

  factory TeacherClassResponse.fromJson(Map<String, dynamic> json) =>
      TeacherClassResponse(id: json['id'] as int, name: json['name'] as String);

  TeacherClass toDomain() => TeacherClass(id: id, name: name);
}

class StudentResponse {
  const StudentResponse({
    required this.id,
    required this.classId,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.middleName,
  });

  final int id;
  final int classId;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String fullName;

  factory StudentResponse.fromJson(Map<String, dynamic> json) =>
      StudentResponse(
        id: json['id'] as int,
        classId: json['class_id'] as int,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        middleName: json['middle_name'] as String?,
        fullName: json['full_name'] as String,
      );

  Student toDomain() => Student(
    id: id,
    classId: classId,
    firstName: firstName,
    lastName: lastName,
    middleName: middleName,
    fullName: fullName,
  );
}

class CreateExitRequestRequest {
  const CreateExitRequestRequest({
    required this.classId,
    required this.studentId,
    required this.reasonType,
    required this.scheduledAt,
    this.customReason,
  });

  factory CreateExitRequestRequest.fromCommand(
    CreateExitRequestCommand command,
  ) => CreateExitRequestRequest(
    classId: command.classId,
    studentId: command.studentId,
    reasonType: command.reasonType.wireName,
    customReason: command.customReason,
    scheduledAt: command.scheduledAt.toUtc().toIso8601String(),
  );

  final int classId;
  final int studentId;
  final String reasonType;
  final String? customReason;
  final String scheduledAt;

  Map<String, dynamic> toJson() => {
    'class_id': classId,
    'student_id': studentId,
    'reason_type': reasonType,
    'custom_reason': customReason,
    'scheduled_at': scheduledAt,
  };
}

class ExitRequestResponse {
  const ExitRequestResponse({
    required this.id,
    required this.classId,
    required this.className,
    required this.studentId,
    required this.studentFullName,
    required this.teacherId,
    required this.teacherFullName,
    required this.reasonType,
    required this.scheduledAt,
    required this.status,
    required this.createdAt,
    this.customReason,
    this.releasedAt,
    this.releasedById,
  });

  final int id;
  final int classId;
  final String className;
  final int studentId;
  final String studentFullName;
  final int teacherId;
  final String teacherFullName;
  final String reasonType;
  final String? customReason;
  final DateTime scheduledAt;
  final String status;
  final DateTime createdAt;
  final DateTime? releasedAt;
  final int? releasedById;

  factory ExitRequestResponse.fromJson(Map<String, dynamic> json) =>
      ExitRequestResponse(
        id: json['id'] as int,
        classId: json['class_id'] as int,
        className: json['class_name'] as String,
        studentId: json['student_id'] as int,
        studentFullName: json['student_full_name'] as String,
        teacherId: json['teacher_id'] as int,
        teacherFullName: json['teacher_full_name'] as String,
        reasonType: json['reason_type'] as String,
        customReason: json['custom_reason'] as String?,
        scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        releasedAt: json['released_at'] == null
            ? null
            : DateTime.parse(json['released_at'] as String).toLocal(),
        releasedById: json['released_by_id'] as int?,
      );

  ExitRequest toDomain() => ExitRequest(
    id: id,
    classId: classId,
    className: className,
    studentId: studentId,
    studentFullName: studentFullName,
    teacherId: teacherId,
    teacherFullName: teacherFullName,
    reasonType: ExitReasonType.fromWire(reasonType),
    customReason: customReason,
    scheduledAt: scheduledAt,
    status: ExitRequestStatus.fromWire(status),
    createdAt: createdAt,
    releasedAt: releasedAt,
    releasedById: releasedById,
  );
}

class ReleaseExitRequestResponse {
  const ReleaseExitRequestResponse({
    required this.id,
    required this.status,
    required this.releasedAt,
    required this.releasedById,
  });

  final int id;
  final String status;
  final DateTime releasedAt;
  final int releasedById;

  factory ReleaseExitRequestResponse.fromJson(Map<String, dynamic> json) =>
      ReleaseExitRequestResponse(
        id: json['id'] as int,
        status: json['status'] as String,
        releasedAt: DateTime.parse(json['released_at'] as String).toLocal(),
        releasedById: json['released_by_id'] as int,
      );

  ReleaseExitRequestResult toDomain() => ReleaseExitRequestResult(
    id: id,
    status: ExitRequestStatus.fromWire(status),
    releasedAt: releasedAt,
    releasedById: releasedById,
  );
}

class ExitRequestStatusResponse {
  const ExitRequestStatusResponse({required this.id, required this.status});

  final int id;
  final String status;

  factory ExitRequestStatusResponse.fromJson(Map<String, dynamic> json) =>
      ExitRequestStatusResponse(
        id: json['id'] as int,
        status: json['status'] as String,
      );
}

class TeacherExitRequestsSnapshotResponse {
  const TeacherExitRequestsSnapshotResponse({
    required this.active,
    required this.history,
  });

  final List<ExitRequestResponse> active;
  final List<ExitRequestResponse> history;

  factory TeacherExitRequestsSnapshotResponse.fromJson(
    Map<String, dynamic> json,
  ) => TeacherExitRequestsSnapshotResponse(
    active: (json['active'] as List<dynamic>? ?? const [])
        .map(
          (item) => ExitRequestResponse.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    history: (json['history'] as List<dynamic>? ?? const [])
        .map(
          (item) => ExitRequestResponse.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
  );

  TeacherExitRequestsSnapshot toDomain() => TeacherExitRequestsSnapshot(
    active: active.map((item) => item.toDomain()).toList(),
    history: history.map((item) => item.toDomain()).toList(),
  );
}
