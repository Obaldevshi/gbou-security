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

      await settle();
      await binding.convertFlutterSurfaceToImage();
      final nav = getIt<GlobalKey<NavigatorState>>(
        instanceName: 'navigatorKey',
      );
      final router = GoRouter.of(nav.currentContext!);
      router.go(AppRoutes.login);
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
      await binding.takeScreenshot('qr-camera-or-permission-fallback');
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
      await binding.takeScreenshot('qr-foreign-origin-rejected');
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
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, qrFixtureUrl);
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
      await binding.takeScreenshot('qr-valid-link-result');
      expect(find.byType(PairingPage), findsOneWidget);
      await binding.takeScreenshot('qr-valid-link-pairing-login');
    },
  );
}
