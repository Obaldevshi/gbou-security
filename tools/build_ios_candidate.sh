#!/usr/bin/env bash
# Local unsigned candidate only. Does not submit, sign, or accept store agreements.
set -euo pipefail
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo 'Requires a Mac with Xcode. No iOS artifact was built.' >&2
  exit 1
fi
task_root="$(cd "$(dirname "$0")/.." && pwd)"
xcode_major="$(xcodebuild -version | awk '/^Xcode / {split($2,a,"."); print a[1]}')"
if [[ -z "$xcode_major" || "$xcode_major" -lt 26 ]]; then
  echo 'Use Xcode 26+ with iOS 26+ SDK for current App Store submissions.' >&2
  exit 1
fi
if [[ "${1:-}" == "--for-store" ]]; then
  python3 "$task_root/tools/prepare_store_privacy.py" --check
fi
cd "$task_root/init-app"
flutter pub get
flutter build ios --release --no-codesign -t lib/main.dart
echo 'Unsigned candidate built. Signing, archive validation, privacy report and real-device tests are still required.'
