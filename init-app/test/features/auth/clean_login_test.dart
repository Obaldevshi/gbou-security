import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/features/auth/domain/entities/current_user.dart';
import 'package:mobile_template/features/auth/domain/entities/user_role.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:mobile_template/features/auth/domain/usecases/login_usecase.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/bloc/login_bloc.dart';
import 'package:mobile_template/features/auth/presentation/pages/login/login_page.dart';
import 'package:mobile_template/features/auth/presentation/widgets/auth_legal_footer.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing_access.dart';
import 'package:mobile_template/generated/l10n/app_localizations.dart';

class _UnusedRepository implements AuthSessionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final role in UserRole.values) {
    test('QR permission is checked for ${role.wireName}', () {
      CurrentUser user({bool active = true, bool temporary = false}) =>
          CurrentUser(
            id: 1,
            login: 'synthetic',
            fullName: 'Synthetic',
            role: role,
            isActive: active,
            mustChangePassword: temporary,
          );
      expect(
        canManageDevicePairing(user()),
        [UserRole.schoolAdmin, UserRole.superAdmin].contains(role),
      );
      expect(canManageDevicePairing(user(active: false)), isFalse);
      expect(canManageDevicePairing(user(temporary: true)), isFalse);
    });
  }
  test(
    'No QR permission before login',
    () => expect(canManageDevicePairing(null), isFalse),
  );

  for (final size in [const Size(320, 640), const Size(800, 480)]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Clean login $size $brightness: no extra primary actions or overflow',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final bloc = LoginBloc(
            loginUsecase: LoginUsecase(_UnusedRepository()),
          );
          addTearDown(bloc.close);
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              locale: const Locale('ru'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('ru')],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: BlocProvider.value(value: bloc, child: const LoginPage()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TextFormField), findsNWidgets(2));
          expect(find.text('Войти'), findsOneWidget);
          expect(find.byType(AuthLegalFooter), findsOneWidget);
          expect(find.text('Лицензии компонентов'), findsOneWidget);
          expect(find.text('Демонстрация'), findsNothing);
          expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
          expect(find.textContaining('Школа определяется'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
