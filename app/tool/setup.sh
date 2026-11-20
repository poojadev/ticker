#!/usr/bin/env bash
# One-time setup: generates the ios/ and android/ folders around the existing
# lib/ (flutter create never overwrites files that already exist), then lets
# Android debug builds talk plain HTTP to the local mock server.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create . --project-name ticker --org com.poojadevraye --platforms ios,android

manifest=android/app/src/debug/AndroidManifest.xml
if ! grep -q usesCleartextTraffic "$manifest"; then
  perl -0pi -e 's|(<manifest[^>]*>)|$1\n    <application android:usesCleartextTraffic="true" />|' "$manifest"
  echo "Enabled cleartext HTTP for Android debug builds."
fi

flutter pub get
echo "Done. Start the server (cd ../server && dart run bin/server.dart), then: flutter run"
