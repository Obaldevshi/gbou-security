// Native ML Kit and real Flutter scanner UI; synthetic payload, network denied.
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_template/app/app_routes.dart';
import 'package:mobile_template/core/bootstrap.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:mobile_template/core/mock_di.dart';
import 'package:mobile_template/core/services/session_service.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing_qr.dart';
import 'package:mobile_template/features/device_pairing/presentation/qr_scanner_page.dart';
import 'package:mobile_template/features/device_pairing/presentation/pairing_page.dart';
import 'package:mobile_template/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:mobile_template/features/auth/data/repositories/mock_auth_session_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_template/features/device_pairing/presentation/pairing_cubit.dart';
import 'package:mobile_template/features/moderation_demo/data/demo_dependencies.dart';
import 'fixtures/qr_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native QR decoder and scanner fallback never navigate foreign origins',
    (tester) async {
      final fixture = File(
        '${Directory.systemTemp.path}/synthetic-pairing.png',
      );
      await fixture.writeAsBytes(base64Decode(qrFixtureBase64));
      final decoder = MobileScannerController(autoStart: false);
      try {
        final capture = await decoder.analyzeImage(
          fixture.path,
          formats: [BarcodeFormat.qrCode],
        );
        expect(
          capture?.barcodes.map((b) => b.rawValue),
          contains(qrFixtureUrl),
        );
        expect(
          PairingQr.requestId(capture!.barcodes.first.rawValue!),
          '11111111-2222-4333-8444-555555555555',
        );
      } finally {
        await decoder.dispose();
        await fixture.delete();
      }
      await bootstrap(
        envFileName: 'assets/env/.env.example',
        configureOverrides: () async {
          await configureMockRepositories();
          getIt<Dio>().httpClientAdapter = NoDemoNetwork();
          await getIt<SessionService>().clearSession();
        },
      );
      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 350));
        }
        expect(tester.takeException(), isNull);
      }

      Future<void> shot(String name) async {
        debugPrint('QR audit: $name');
        await tester.pump(const Duration(milliseconds: 150));
        await binding.takeScreenshot(name).timeout(const Duration(seconds: 25));
      }

      await settle();
      await binding.convertFlutterSurfaceToImage();
      final nav = getIt<GlobalKey<NavigatorState>>(
        instanceName: 'navigatorKey',
      );
      final router = GoRouter.of(nav.currentContext!);
      // Scanner is deliberately admin-only, never a public login action.
      router.go(AppRoutes.login);
      await settle();
      expect(find.text('Подключить Raspberry по QR'), findsNothing);
      // A phone's ordinary camera can open the web QR route even when the
      // school server is stopped. Its isolated central admin login is allowed
      // without a teacher/guard session. This is not an Android App Links test.
      router.go(
        '${AppRoutes.connectDevices}/11111111-2222-4333-8444-555555555555',
      );
      await settle();
      expect(find.byType(PairingPage), findsOneWidget);
      expect(getIt<SessionService>().currentUser, isNull);
      await shot('qr-fresh-unbound-admin-login');
      router.go(AppRoutes.login);
      await settle();
      await getIt<AuthSessionRepository>().login(
        login: 'teacher.demo',
        password: MockAuthSessionRepository.password,
      );
      await getIt<SessionService>().dismissPinOffer();
      await settle();
      router.go(AppRoutes.scanDevice);
      await settle();
      expect(
        find.byType(QrScannerPage),
        findsNothing,
        reason: 'A teacher cannot open the admin-only scanner by route',
      );
      await getIt<SessionService>().clearSession();
      await settle();
      await getIt<AuthSessionRepository>().login(
        login: 'school.admin',
        password: MockAuthSessionRepository.password,
      );
      await getIt<SessionService>().dismissPinOffer();
      await settle();
      router.go(AppRoutes.schoolProfile);
      await settle();
      final scan = find.text('Подключить Raspberry по QR');
      await tester.ensureVisible(scan);
      await tester.tap(scan);
      await settle();
      expect(find.byType(QrScannerPage), findsOneWidget);
      if (const bool.fromEnvironment('QR_TEST_CAMERA')) {
        final enable = find.text('Включить камеру');
        await tester.scrollUntilVisible(
          enable,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(enable);
        await settle();
        final scanner = tester.widget<MobileScanner>(
          find.byType(MobileScanner),
        );
        for (
          var i = 0;
          i < 80 &&
              !scanner.controller!.value.isRunning &&
              scanner.controller!.value.error == null;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        if (const bool.fromEnvironment('QR_TEST_EXPECT_DENIED')) {
          expect(scanner.controller!.value.hasCameraPermission, isFalse);
          expect(find.textContaining('Камера недоступна'), findsOneWidget);
        } else {
          expect(
            scanner.controller!.value.hasCameraPermission,
            isTrue,
            reason: '${scanner.controller!.value.error?.errorCode}',
          );
          expect(scanner.controller!.value.isRunning, isTrue);
          binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          await settle();
          expect(scanner.controller!.value.isRunning, isFalse);
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await settle();
          expect(scanner.controller!.value.isRunning, isTrue);
        }
      }
      await shot('qr-camera-or-permission-fallback');
      await tester.scrollUntilVisible(
        find.byType(TextField),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byType(TextField),
        'https://foreign.invalid/#/connect/11111111-2222-4333-8444-555555555555',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      final open = find.text('Открыть подключение');
      await tester.scrollUntilVisible(
        open,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(open);
      await settle();
      expect(open.hitTestable(), findsOneWidget);
      await tester.tap(open);
      await settle();
      expect(find.byType(QrScannerPage), findsOneWidget);
      await shot('qr-foreign-origin-rejected');
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await settle();
      await tester.enterText(find.byType(TextField), qrFixtureUrl);
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        qrFixtureUrl,
      );
      await tester.scrollUntilVisible(
        open,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(open);
      await settle();
      expect(open.hitTestable(), findsOneWidget);
      await tester.tap(open);
      await settle();
      for (
        var i = 0;
        i < 40 && find.byType(PairingPage).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await shot('qr-valid-link-result');
      expect(find.byType(PairingPage), findsOneWidget);
      await shot('qr-valid-link-pairing-login');

      // End-to-end control-plane UI against an in-memory pairing repository.
      // Never scan, approve or activate the production Raspberry in this audit.
      Future<void> tapPairing(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await settle();
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            140,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
        await settle();
        expect(finder.hitTestable(), findsOneWidget);
        await tester.tap(finder);
        await settle();
      }

      await tester.enterText(find.byType(TextField).at(0), 'admin-demo');
      await tester.enterText(find.byType(TextField).at(1), 'mock-only');
      await tapPairing(
        find.widgetWithText(FilledButton, 'Войти для настройки'),
      );
      await tapPairing(find.byKey(const ValueKey('building-1-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Корпус 1').last);
      await settle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '000000');
      await tapPairing(
        find.widgetWithText(FilledButton, 'Подключить устройство'),
      );
      await shot('qr-primary-confirm-building');
      await tapPairing(
        find.widgetWithText(FilledButton, 'Подключить устройство').last,
      );
      expect(find.text('Демо-код: 123456'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '123456');
      await tapPairing(
        find.widgetWithText(FilledButton, 'Подключить устройство'),
      );
      await tapPairing(
        find.widgetWithText(FilledButton, 'Подключить устройство').last,
      );
      final cubit = tester
          .element(find.byType(PairingPage))
          .read<PairingCubit>();
      expect(cubit.state.school!.devices.single.state, 'pending');
      expect(cubit.state.school!.devices.single.buildingId, 1);
      expect(cubit.state.school!.hasPrimaryFor(1), isFalse);
      await shot('qr-primary-pending');
      await tapPairing(
        find.widgetWithText(TextButton, 'Активировать главную Raspberry'),
      );
      final activate = find.widgetWithText(
        FilledButton,
        'Активировать главную Raspberry',
      );
      expect(tester.widget<FilledButton>(activate).onPressed, isNull);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      await settle();
      await shot('qr-activation-safety-large-text');
      await tapPairing(find.byType(CheckboxListTile).at(0));
      expect(tester.widget<FilledButton>(activate).onPressed, isNull);
      await tapPairing(find.byType(CheckboxListTile).at(1));
      expect(tester.widget<FilledButton>(activate).onPressed, isNotNull);
      await tapPairing(activate);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await settle();
      expect(cubit.state.school!.hasPrimaryFor(1), isTrue);
      expect(cubit.state.school!.hasPrimaryFor(2), isFalse);
      await shot('qr-primary-active-fixture-only');
    },
  );
}
