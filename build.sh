#!/bin/bash
# Plain-clang build (no Theos needed).
set -euo pipefail
cd "$(dirname "$0")"

OUT="${1:-LCTweakNoBackup.dylib}"

xcrun --sdk iphoneos clang \
  -arch arm64 \
  -dynamiclib \
  -fobjc-arc \
  -miphoneos-version-min=15.0 \
  -Wall \
  -framework Foundation \
  -framework UIKit \
  -o "$OUT" \
  LCTweakNoBackup.m

echo "built: $(pwd)/$OUT"
file "$OUT"
