import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_template/app/theme/app_theme.dart';
import 'package:mobile_template/features/device_pairing/data/pairing_repository.dart';
import 'package:mobile_template/features/device_pairing/domain/pairing.dart';
import 'package:mobile_template/features/device_pairing/presentation/pairing_cubit.dart';
import 'package:mobile_template/features/device_pairing/presentation/pairing_page.dart';
import 'package:mobile_template/generated/l10n/app_localizations.dart';

void main() {
  testWidgets('Wrong QR code reveals error above a long setup form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = PairingCubit(
      PairingActions(MockPairingRepository()),
      'fixture-only',
    );
    addTearDown(cubit.close);
    await cubit.login('admin-demo', 'mock-only');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: BlocProvider.value(value: cubit, child: const PairingPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    await cubit.approve(1, 'primary', '000000');
    await tester.pumpAndSettle();
    expect(find.text('Демо-код: 123456').hitTestable(), findsOneWidget);
    expect(cubit.state.school!.devices, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
