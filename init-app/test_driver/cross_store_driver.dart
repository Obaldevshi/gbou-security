import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  // The Flutter driver installs/removes its test APK per run. Configure only the
  // dedicated emulator's test package, after install and before resuming the VM.
  final mode = Platform.environment['GBOU_QR_TEST_PERMISSION'];
  if (mode == 'grant' || mode == 'deny') {
    final sdk =
        Platform.environment['ANDROID_SDK_ROOT'] ??
        '${Platform.environment['LOCALAPPDATA']}/Android/Sdk';
    Future<void> adb(List<String> args) async {
      final result = await Process.run('$sdk/platform-tools/adb.exe', [
        '-s',
        'emulator-5554',
        'shell',
        'pm',
        ...args,
      ]);
      if (result.exitCode != 0) {
        throw StateError('Test camera permission setup failed');
      }
    }

    const package = 'ru.obaldevshi.gbou_security';
    const permission = 'android.permission.CAMERA';
    await adb([
      'clear-permission-flags',
      package,
      permission,
      'user-set',
      'user-fixed',
    ]);
    if (mode == 'grant') {
      await adb(['grant', package, permission]);
    } else {
      await adb(['revoke', package, permission]);
      await adb([
        'set-permission-flags',
        package,
        permission,
        'user-set',
        'user-fixed',
      ]);
    }
  }
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final folder = Directory('../artifacts/visual-audit-cross-store');
      await folder.create(recursive: true);
      await File('${folder.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
