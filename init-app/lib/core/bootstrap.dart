import 'package:mobile_template/app/app.dart';
import 'package:mobile_template/core/di/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile_template/core/utils/app_licenses.dart';

Future<void> bootstrap({
  required String envFileName,
  Future<void> Function()? configureOverrides,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAssetLicenses();
  await dotenv.load(fileName: envFileName);
  await configureDependencies();
  await configureOverrides?.call();
  runApp(const MobileTemplateApp());
}
