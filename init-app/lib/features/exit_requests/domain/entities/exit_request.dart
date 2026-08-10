import 'package:equatable/equatable.dart';

enum ExitReasonType {
  parentNote('parent_note'),
  health('health'),
  other('other');

  const ExitReasonType(this.wireName);

  final String wireName;

  static ExitReasonType fromWire(String value) => switch (value) {
    'parent_note' => ExitReasonType.parentNote,
    'health' => ExitReasonType.health,
    'other' => ExitReasonType.other,
    _ => throw FormatException('Unknown exit reason type: $value'),
  };
}

enum ExitRequestStatus {
  pending('pending'),
  released('released');

  const ExitRequestStatus(this.wireName);

  final String wireName;

  static ExitRequestStatus fromWire(String value) => switch (value) {
    'pending' => ExitRequestStatus.pending,
    'released' => ExitRequestStatus.released,
    _ => throw FormatException('Unknown exit request status: $value'),
  };
}

class ExitRequest extends Equatable {
  const ExitRequest({
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
  final ExitReasonType reasonType;
  final String? customReason;
  final DateTime scheduledAt;
  final ExitRequestStatus status;
  final DateTime createdAt;
  final DateTime? releasedAt;
  final int? releasedById;

  @override
  List<Object?> get props => [
    id,
    classId,
    className,
    studentId,
    studentFullName,
    teacherId,
    teacherFullName,
    reasonType,
    customReason,
    scheduledAt,
    status,
    createdAt,
    releasedAt,
    releasedById,
  ];
}

class ReleaseExitRequestResult extends Equatable {
  const ReleaseExitRequestResult({
    required this.id,
    required this.status,
    required this.releasedAt,
    required this.releasedById,
  });

  final int id;
  final ExitRequestStatus status;
  final DateTime releasedAt;
  final int releasedById;

  @override
  List<Object?> get props => [id, status, releasedAt, releasedById];
}

class TeacherExitRequestsSnapshot extends Equatable {
  const TeacherExitRequestsSnapshot({
    required this.active,
    required this.history,
  });

  final List<ExitRequest> active;
  final List<ExitRequest> history;

  @override
  List<Object?> get props => [active, history];
}

class CreateExitRequestCommand extends Equatable {
  const CreateExitRequestCommand({
    required this.classId,
    required this.studentId,
    required this.reasonType,
    required this.scheduledAt,
    this.customReason,
  });

  final int classId;
  final int studentId;
  final ExitReasonType reasonType;
  final String? customReason;
  final DateTime scheduledAt;

  @override
  List<Object?> get props => [
    classId,
    studentId,
    reasonType,
    customReason,
    scheduledAt,
  ];
}
