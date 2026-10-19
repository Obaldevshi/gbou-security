import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/theme/app_theme.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/shell/presentation/pages/main_navigation.dart';
import 'package:mobile_template/generated/l10n/app_localizations.dart';

void main() {
  for (final width in [600.0, 800.0, 1024.0, 1440.0]) {
    for (final scale in [1.0, 1.4]) {
      testWidgets('Navigation fits $width px and text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        getIt.registerSingleton<SessionService>(SessionService.inMemory());
        addTearDown(getIt.reset);
        final router = GoRouter(
          initialLocation: '/a',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (_, _, shell) => MainNavigation(navigationShell: shell),
              branches: [
                for (final route in ['a', 'b', 'c', 'd'])
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/$route',
                        builder: (_, _) => Center(child: Text('Page $route')),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Мои ученики').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('Мои ученики'));
        await tester.pumpAndSettle();
        expect(find.text('Page d'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
