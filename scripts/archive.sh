#!/bin/zsh
# App Store 제출용 아카이브 + .ipa 생성
#   ./scripts/archive.sh            → build/GAlarm.xcarchive, build/export/*.ipa 생성
#   ./scripts/archive.sh --upload   → 생성 후 App Store Connect 로 업로드 (Xcode 에 로그인된 계정 사용)
# 업로드 전에 App Store Connect 에 앱 레코드(번들 ID com.codemaki.WatchAlarm)가 있어야 한다.
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ARCHIVE=build/GAlarm.xcarchive
EXPORT_DIR=build/export
OPTIONS=scripts/ExportOptions.plist

xcodegen generate

rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild archive \
  -project WatchAlarm.xcodeproj \
  -scheme WatchAlarm \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates

if [[ "${1:-}" == "--upload" ]]; then
  UPLOAD_OPTIONS=build/ExportOptions-upload.plist
  cp "$OPTIONS" "$UPLOAD_OPTIONS"
  plutil -replace destination -string upload "$UPLOAD_OPTIONS"
  OPTIONS="$UPLOAD_OPTIONS"
fi

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$OPTIONS" \
  -allowProvisioningUpdates

echo "완료: $ARCHIVE"
[[ "${1:-}" == "--upload" ]] && echo "App Store Connect 업로드 요청됨 (처리 완료까지 수 분~수십 분)" || ls "$EXPORT_DIR"
