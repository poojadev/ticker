#!/usr/bin/env bash
# One-time (and safe to re-run) platform setup for the Ticker app.
#
#   1. Generates ios/ and android/ around the existing lib/.
#      `flutter create` never overwrites files that already exist.
#   2. iOS: allows plain-HTTP/WebSocket to local addresses (ATS) and adds the
#      Local Network prompt text. Without these, a PHYSICAL iPhone can't reach
#      the mock server on your Mac. The Simulator doesn't need them.
#   3. Android: allows cleartext HTTP in DEBUG builds only.
#
# Every step checks before it changes anything, so running it twice is a no-op.
set -euo pipefail
cd "$(dirname "$0")/.."

# ── 1. Platform folders ─────────────────────────────────────────────────────
flutter create . \
  --project-name ticker \
  --org com.poojadevraye \
  --platforms ios,android

# flutter create adds a counter-app widget test when test/widget_test.dart is
# missing. It references a MyApp class we don't have, so remove it.
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
  echo "Removed the template counter test."
fi

# ── 2. iOS Info.plist ───────────────────────────────────────────────────────
plist=ios/Runner/Info.plist
pb=/usr/libexec/PlistBuddy

if ! "$pb" -c "Print :NSAppTransportSecurity:NSAllowsLocalNetworking" "$plist" >/dev/null 2>&1; then
  # The dict may not exist yet; "Add" fails harmlessly if it does.
  "$pb" -c "Add :NSAppTransportSecurity dict" "$plist" 2>/dev/null || true
  "$pb" -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$plist"
  echo "iOS: enabled NSAllowsLocalNetworking."
fi

if ! "$pb" -c "Print :NSLocalNetworkUsageDescription" "$plist" >/dev/null 2>&1; then
  "$pb" -c "Add :NSLocalNetworkUsageDescription string 'Ticker connects to the mock market server running on your Mac.'" "$plist"
  echo "iOS: added NSLocalNetworkUsageDescription."
fi

# ── 3. Android debug manifest ───────────────────────────────────────────────
manifest=android/app/src/debug/AndroidManifest.xml
if ! grep -q usesCleartextTraffic "$manifest"; then
  # Insert <application android:usesCleartextTraffic="true" /> right after the
  # opening <manifest ...> tag. Gradle merges it into the main manifest.
  perl -0pi -e 's|(<manifest[^>]*>)|$1\n    <application android:usesCleartextTraffic="true" />|' "$manifest"
  echo "Android: enabled cleartext HTTP for debug builds."
fi

flutter pub get
echo
echo "Done. Start the server (cd ../server && dart run bin/server.dart), then: flutter run"
