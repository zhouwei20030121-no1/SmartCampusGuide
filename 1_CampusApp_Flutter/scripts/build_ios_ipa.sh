#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

API_BASE_URL="${API_BASE_URL:-}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not installed or not on PATH."
  exit 1
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "CocoaPods is not installed or not on PATH."
  exit 1
fi

flutter pub get

(
  cd ios
  pod install
)

args=(build ipa --release)

if [ -n "$EXPORT_OPTIONS_PLIST" ]; then
  args+=(--export-options-plist="$EXPORT_OPTIONS_PLIST")
fi

if [ -n "$API_BASE_URL" ]; then
  args+=(--dart-define="API_BASE_URL=$API_BASE_URL")
fi

flutter "${args[@]}"
