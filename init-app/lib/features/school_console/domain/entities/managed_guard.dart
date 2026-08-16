import 'package:equatable/equatable.dart';

class ManagedGuard extends Equatable {
  const ManagedGuard({
    required this.id,
    required this.login,
    required this.fullName,
    required this.isActive,
    this.phone,
  });
  final int id;
  final String login;
  final String fullName;
  final String? phone;
  final bool isActive;
  @override
  List<Object?> get props => [id, login, fullName, phone, isActive];
}

class GuardDraft extends Equatable {
  const GuardDraft({
    required this.login,
    required this.fullName,
    this.phone,
    this.password,
  });
  final String login;
  final String fullName;
  final String? phone;
  final String? password;
  Map<String, dynamic> toJson({required bool includePassword}) => {
    'login': login,
    'full_name': fullName,
    'phone': phone,
    if (includePassword || password != null) 'password': password,
  };
  @override
  List<Object?> get props => [login, fullName, phone, password];
}
