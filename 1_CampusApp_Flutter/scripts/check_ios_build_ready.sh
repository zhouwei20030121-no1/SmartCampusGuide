#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

missing=0

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf '[ok] %s: %s\n' "$name" "$(command -v "$name")"
  else
    printf '[missing] %s\n' "$name"
    missing=1
  fi
}

check_file() {
  local path="$1"
  if [ -e "$path" ]; then
    printf '[ok] %s\n' "$path"
  else
    printf '[missing] %s\n' "$path"
    missing=1
  fi
}

echo '== Toolchain =='
check_command flutter
check_command xcodebuild
check_command pod

if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -version
fi

echo
echo '== Flutter project =='
check_file pubspec.yaml
check_file ios/Runner.xcworkspace/contents.xcworkspacedata
check_file ios/Runner.xcodeproj/project.pbxproj
check_file ios/Podfile
check_file ios/Flutter/Generated.xcconfig
check_file ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage

echo
echo '== Signing hints =='
if grep -q 'DEVELOPMENT_TEAM' ios/Runner.xcodeproj/project.pbxproj; then
  echo '[ok] DEVELOPMENT_TEAM appears in Xcode project'
else
  echo '[warn] DEVELOPMENT_TEAM is not configured in the Xcode project'
fi

if grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.swu.smartCampusGuide' ios/Runner.xcodeproj/project.pbxproj; then
  echo '[warn] Bundle identifier is still the default: com.swu.smartCampusGuide'
fi

echo
if [ "$missing" -eq 0 ]; then
  echo 'Ready for: flutter build ipa --release'
else
  echo 'Not ready yet. Run flutter pub get, then cd ios && pod install, and configure signing.'
  exit 1
fi
