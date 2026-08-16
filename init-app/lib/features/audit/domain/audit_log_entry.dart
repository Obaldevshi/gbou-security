import 'package:equatable/equatable.dart';

class AuditLogEntry extends Equatable {
  const AuditLogEntry({
    required this.id,
    required this.actorName,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.createdAt,
    this.schoolName,
    this.ipAddress,
  });

  final int id;
  final String actorName;
  final String? schoolName;
  final String method;
  final String path;
  final int statusCode;
  final String? ipAddress;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    actorName,
    schoolName,
    method,
    path,
    statusCode,
    ipAddress,
    createdAt,
  ];
}

class AuditLogPageData {
  const AuditLogPageData({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  final List<AuditLogEntry> items;
  final int total;
  final int page;
  final int pageSize;
}
