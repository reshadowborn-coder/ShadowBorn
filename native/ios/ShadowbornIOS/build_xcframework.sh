#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT_HEADERS="${GODOT_HEADERS:-}"
OUT_DIR="${OUT_DIR:-$ROOT/build/native-ios}"

if [[ -z "$GODOT_HEADERS" || ! -d "$GODOT_HEADERS" ]]; then
  echo "GODOT_HEADERS must point at extracted Godot 4.4.1 iOS headers" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"
rm -rf "$OUT_DIR/ShadowbornIOS.debug.xcframework" "$OUT_DIR/ShadowbornIOS.release.xcframework"

cd "$ROOT"

for TARGET in release_debug release; do
  scons -Q -f native/ios/ShadowbornIOS/SConstruct \
    godot_headers="$GODOT_HEADERS" \
    out_dir="$OUT_DIR" \
    target="$TARGET" \
    arch=arm64 \
    simulator=no

  LIB="$OUT_DIR/libShadowbornIOS.arm64.iphoneos.${TARGET}.a"
  test -s "$LIB"

  if [[ "$TARGET" == "release_debug" ]]; then
    FRAMEWORK="$OUT_DIR/ShadowbornIOS.debug.xcframework"
  else
    FRAMEWORK="$OUT_DIR/ShadowbornIOS.release.xcframework"
  fi

  xcodebuild -create-xcframework \
    -library "$LIB" \
    -output "$FRAMEWORK" >/dev/null

  test -f "$FRAMEWORK/Info.plist"
done

cp native/ios/ShadowbornIOS/ShadowbornIOS.gdip.in "$OUT_DIR/ShadowbornIOS.gdip"

printf '%s\n' \
  "godot_version=4.4.1-stable" \
  "min_ios=16.0" \
  "arch=arm64" \
  "debug_binary=ShadowbornIOS.debug.xcframework" \
  "release_binary=ShadowbornIOS.release.xcframework" \
  > "$OUT_DIR/native-bridge-manifest.txt"

echo "ShadowbornIOS native bridge built successfully in $OUT_DIR"
