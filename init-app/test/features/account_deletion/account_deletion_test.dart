import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/auth/domain/entities/auth_session.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';
import 'package:mobile_template/features/account_deletion/data/account_deletion_repository.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Object Function(RequestOptions) respond;
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(options);
    return ResponseBody.fromString(
      jsonEncode(respond(options)),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const base = 'https://school.example/api/v1',
      central = 'https://central.example/api/v1';
  test(
    'mirror deletion uses isolated deletion-only token and verifies identity',
    () async {
      final session = SessionService.inMemory();
      await session.establishSession(
        const AuthSession(
          accessToken: 'school-token',
          tokenType: 'bearer',
          expiresIn: 3600,
          user: CurrentUser(
            id: -7,
            login: 'synthetic.admin',
            fullName: 'Демо',
            role: UserRole.schoolAdmin,
            schoolId: 2,
            isActive: true,
          ),
        ),
      );
      final schoolAdapter = _Adapter(
        (_) => {
          'data': {'authority': 'central', 'user_id': 7, 'can_delete': true},
        },
      );
      final centralAdapter = _Adapter(
        (r) => r.path.endsWith('account-deletion-session')
            ? {
                'data': {
                  'access_token': 'deletion-only-token',
                  'user': {'id': 7, 'role': 'school_admin', 'school_id': 2},
                },
              }
            : {'message': 'deleted'},
      );
      final dio = Dio()..httpClientAdapter = schoolAdapter;
      final repo = AccountDeletionRepositoryImpl(
        dio,
        base,
        session,
        central,
        centralClientFactory: () => Dio()..httpClientAdapter = centralAdapter,
      );
      expect(
        (await repo.delete('synthetic-password', 'УДАЛИТЬ')).isRight(),
        isTrue,
      );
      expect(centralAdapter.calls.length, 2);
      expect(
        centralAdapter.calls.first.path,
        '$central/auth/account-deletion-session',
      );
      expect(
        centralAdapter.calls.last.path,
        '$central/users/delete-account-with-session',
      );
      expect(
        centralAdapter.calls.last.headers['Authorization'],
        'Bearer deletion-only-token',
      );
      expect(centralAdapter.calls.every((r) => !r.followRedirects), isTrue);
      expect(schoolAdapter.calls.length, 1);
      expect(
        session.getAccessToken(),
        'school-token',
        reason: 'UI clears only after confirmed success',
      );
    },
  );
  test('different central account is never deleted', () async {
    final session = SessionService.inMemory();
    await session.establishSession(
      const AuthSession(
        accessToken: 'school-token',
        tokenType: 'bearer',
        expiresIn: 3600,
        user: CurrentUser(
          id: -7,
          login: 'synthetic.admin',
          fullName: 'Демо',
          role: UserRole.schoolAdmin,
          schoolId: 2,
          isActive: true,
        ),
      ),
    );
    final school = _Adapter(
      (_) => {
        'data': {'authority': 'central', 'user_id': 7, 'can_delete': true},
      },
    );
    final other = _Adapter(
      (_) => {
        'data': {
          'access_token': 'other',
          'user': {'id': 99, 'role': 'school_admin', 'school_id': 2},
        },
      },
    );
    final repo = AccountDeletionRepositoryImpl(
      Dio()..httpClientAdapter = school,
      base,
      session,
      central,
      centralClientFactory: () => Dio()..httpClientAdapter = other,
    );
    expect(
      (await repo.delete('synthetic-password', 'УДАЛИТЬ')).isLeft(),
      isTrue,
    );
    expect(other.calls.length, 1);
    expect(session.getAccessToken(), 'school-token');
  });
}
