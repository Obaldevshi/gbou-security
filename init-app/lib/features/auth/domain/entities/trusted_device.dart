import 'package:equatable/equatable.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';

class TrustedDevice extends Equatable {
  const TrustedDevice({
    required this.id,
    required this.name,
    required this.expiresAt,
    required this.createdAt,
    this.lastUsedAt,
  });

  final int id;
  final String name;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  factory TrustedDevice.fromJson(Map<String, dynamic> json) => TrustedDevice(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    lastUsedAt: json['last_used_at'] == null
        ? null
        : DateTime.parse(json['last_used_at'] as String),
  );

  @override
  List<Object?> get props => [id, name, expiresAt, createdAt, lastUsedAt];
}

class TrustedDeviceCredentials extends Equatable {
  const TrustedDeviceCredentials({
    required this.device,
    required this.refreshToken,
  });

  final TrustedDevice device;
  final String refreshToken;

  @override
  List<Object> get props => [device, refreshToken];
}

class TrustedSessionResult extends Equatable {
  const TrustedSessionResult({
    required this.session,
    required this.refreshToken,
    required this.trustedDeviceId,
  });

  final AuthSession session;
  final String refreshToken;
  final int trustedDeviceId;

  @override
  List<Object> get props => [session, refreshToken, trustedDeviceId];
}
