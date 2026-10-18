import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _registered = false;

void registerAssetLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Quicksand',
    ], await rootBundle.loadString('assets/licenses/Quicksand-OFL.txt'));
    yield LicenseEntryWithLineBreaks(
      const ['Material SVG icons'],
      await rootBundle.loadString(
        'assets/licenses/Material-Icons-Apache-2.0.txt',
      ),
    );
    yield LicenseEntryWithLineBreaks(const [
      'GBOU Security asset notices',
    ], await rootBundle.loadString('assets/licenses/ASSET_NOTICES.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'Android runtime dependencies',
    ], await rootBundle.loadString('assets/licenses/ANDROID_NOTICES.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'DejaVu font used in server PDF reports',
    ], await rootBundle.loadString('assets/licenses/DejaVu-LICENSE.txt'));
    yield LicenseEntryWithLineBreaks(
      const ['Protocol Buffers used by AndroidX DataStore'],
      await rootBundle.loadString('assets/licenses/Protobuf-BSD-3-Clause.txt'),
    );
  });
}

void showAppLicenses(BuildContext context) =>
    showLicensePage(context: context, applicationName: 'GBOU Security');
