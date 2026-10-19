# Project-local workaround for Flutter dev-only plugin registrant state after UI tests.
# No SDK patching, signing-key generation, account changes or uploads.
param([switch]$ForRuStore, [switch]$ForGooglePlay, [switch]$BuildAppBundle)
$ErrorActionPreference = 'Stop'
$projectRootPath = Split-Path -Parent $PSScriptRoot
$taskPython = Join-Path $projectRootPath 'init-api/.venv/Scripts/python.exe'
if (!(Test-Path -LiteralPath $taskPython)) { throw 'Prepare the project Python venv first.' }
if ($ForRuStore -or $ForGooglePlay) {
    & $taskPython (Join-Path $projectRootPath 'tools/prepare_store_privacy.py') --check
    if ($LASTEXITCODE -ne 0) { throw 'Owner-approved privacy policy is required before a store release.' }
    & $taskPython (Join-Path $projectRootPath 'tools/prepare_store_privacy.py')
    if ($LASTEXITCODE -ne 0) { throw 'Privacy HTML generation failed' }
}
if (!(Test-Path -LiteralPath (Join-Path $projectRootPath 'init-app/android/key.properties'))) {
    throw 'Configure the permanent release signer first. Debug signing is not allowed.'
}
Push-Location (Join-Path $projectRootPath 'init-app')
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'pub get failed' }
    & flutter build apk --release --config-only -t lib/main.dart
    if ($LASTEXITCODE -ne 0) { throw 'Release metadata generation failed' }
    $registrant = 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java'
    if (Select-String -Path $registrant -SimpleMatch 'dev.flutter.plugins.integration_test') {
        throw 'Development-only integration plugin is still present. Do not publish this build.'
    }
    & flutter build apk --release --no-pub -t lib/main.dart
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed' }
    & $taskPython (Join-Path $projectRootPath 'tools/verify_android_release.py')
    if ($LASTEXITCODE -ne 0) { throw 'Release verification failed' }
    if ($BuildAppBundle -or $ForGooglePlay) {
        & flutter build appbundle --release --no-pub -t lib/main.dart
        if ($LASTEXITCODE -ne 0) { throw 'App Bundle build failed' }
        & $taskPython (Join-Path $projectRootPath 'tools/verify_android_bundle.py')
        if ($LASTEXITCODE -ne 0) { throw 'App Bundle verification failed' }
    }
} finally {
    Pop-Location
}
