import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/features/device_pairing/presentation/qr_scanner_page.dart';
import 'package:mobile_template/generated/l10n/app_localizations.dart';

void main() {
  testWidgets('320px, enlarged text: manual QR works without opening camera', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: AppRoutes.scanDevice,
      routes: [
        GoRoute(
          path: AppRoutes.scanDevice,
          builder: (_, _) => const QrScannerPage(),
        ),
        GoRoute(
          path: '/connect/:id',
          builder: (_, state) =>
              Scaffold(body: Text('REQUEST ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
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
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // No camera method channel is mocked: opening this screen must not call it.
    await tester.scrollUntilVisible(
      find.text('Включить камеру'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Включить камеру'), findsOneWidget);
    final input = find.byType(TextField);
    await tester.scrollUntilVisible(
      input,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      input,
      'https://foreign.invalid/#/connect/11111111-2222-4333-8444-555555555555',
    );
    final open = find.text('Открыть подключение');
    await tester.scrollUntilVisible(
      open,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(QrScannerPage), findsOneWidget);
    await tester.scrollUntilVisible(
      input,
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      input,
      'https://gbousecurity.ru/#/connect/11111111-2222-4333-8444-555555555555',
    );
    await tester.scrollUntilVisible(
      open,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(
      find.text('REQUEST 11111111-2222-4333-8444-555555555555'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
