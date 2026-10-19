param([ValidateSet('Store','Visual','QrGrant','QrDeny')][string]$Scenario='Store')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$targets=@{
  Store='integration_test/store_readiness_test.dart'
  Visual='integration_test/visual_audit_test.dart'
  QrGrant='integration_test/qr_scanner_test.dart'
  QrDeny='integration_test/qr_scanner_test.dart'
}
$target=$targets[$Scenario]
$driver=if ($Scenario -eq 'Store') {'test_driver/store_driver.dart'} else {'test_driver/cross_store_driver.dart'}
Push-Location (Join-Path $taskRoot 'init-app')
try {
  # --no-pub also skips registrant regeneration in Flutter 3.44. Regenerate
  # debug metadata after a release build; do not patch the SDK or Java output.
  & flutter build apk --debug --config-only -t $target
  if ($LASTEXITCODE -ne 0) {throw 'Debug metadata generation failed'}
  if (!(Select-String -Path 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java' -SimpleMatch 'dev.flutter.plugins.integration_test')) {
    throw 'Integration plugin absent; test must not run with release metadata.'
  }
  $argsList=@('drive',"--driver=$driver","--target=$target",'-d','emulator-5554','--no-pub')
  if ($Scenario -eq 'QrGrant' -or $Scenario -eq 'QrDeny') {
    $env:GBOU_QR_TEST_PERMISSION=if ($Scenario -eq 'QrGrant') {'grant'} else {'deny'}
    $argsList+='--dart-define=QR_TEST_CAMERA=true'
    if ($Scenario -eq 'QrDeny') {$argsList+='--dart-define=QR_TEST_EXPECT_DENIED=true'}
  }
  & flutter @argsList
  if ($LASTEXITCODE -ne 0) {throw 'Android integration audit failed'}
} finally {
  Remove-Item Env:GBOU_QR_TEST_PERMISSION -ErrorAction SilentlyContinue
  Pop-Location
}
