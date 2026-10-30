#!/usr/bin/env bash
# bloodborne-ios: one app. Builds bloodborne-launcher's iOS app with the game inside: the runtime
# core and GPU library (as scripts/build-app.sh), app/app_main.c built for the launcher
# (BB_IOS_IN_LAUNCHER: its Play calls bb_ios_start_game) and the recompiled library in the app's
# Frameworks; signs it with the player's Apple team and installs it (its Documents stay).
#   BB_IOS_TEAM=XXXXXXXXXX BB_IOS_DEVICE=<udid> [BB_LAUNCHER=<launcher checkout>] scripts/build-launcher.sh
# BB_LAUNCHER: the launcher to build (default launcher/; it needs npm ci there).
# BB_LAUNCHER_CONFIG: release (default) or debug. Release: the launcher's own code in the app's low
# address space is far smaller (debug: a 264 MB Bloodborne.debug.dylib), and the game needs that room.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
: "${BB_IOS_TEAM:?the Apple team ID (Xcode → Settings → Accounts)}" "${BB_IOS_DEVICE:?the iPhone UDID (xcrun devicectl list devices)}"
launcher=${BB_LAUNCHER:-$PWD/launcher}
config=${BB_LAUNCHER_CONFIG:-release}
bash runtime/scripts/ios/build-core.sh >/dev/null
bash runtime/scripts/ios/build-gpu.sh >/dev/null
deps=$PWD/runtime/deps/ios-arm64/lib gpu=$PWD/runtime/out/ios/gpu out=$PWD/out/launcher
mkdir -p "$out"
# The app's side of the game, for the launcher.
cc=(xcrun -sdk iphoneos clang -target arm64-apple-ios18.0 -O2 -g -DBB_IOS_IN_LAUNCHER -I"$PWD/runtime/deps/ios-arm64/include")
"${cc[@]}" -c app/app_main.c -o "$out/app_main.o"
"${cc[@]}" -fobjc-arc -c app/metal_test.m -o "$out/metal_test.o"
"${cc[@]}" -fobjc-arc -c app/orientation.m -o "$out/orientation.o"
rm -f "$out/libbbapp.a"
xcrun -sdk iphoneos ar rcs "$out/libbbapp.a" "$out/app_main.o" "$out/metal_test.o" "$out/orientation.o"
libs=(-Wl,-force_load,"$out/libbbapp.a" -Wl,-u,_bb_ios_start_game "$PWD/runtime/out/ios/libbbios.a"
      "$gpu/libbbgpu.a" "$gpu/third_party/sirit/src/libsirit.a"
      "$deps"/libspirv-cross-{msl,glsl,core}.a "$deps"/lib{fmt,miniz,xxhash}.a
      "$deps"/lib{avformat,avcodec,swscale,swresample,avutil}.a "$deps"/libboost_container.a "$deps/libSDL3.a")
frameworks=()
for f in AVFoundation AudioToolbox CoreAudio CoreBluetooth CoreFoundation CoreGraphics CoreHaptics \
         CoreMedia CoreMotion CoreVideo Foundation GameController IOSurface Metal MetalFX OpenGLES \
         QuartzCore Security UIKit UniformTypeIdentifiers VideoToolbox; do frameworks+=(-framework "$f"); done
(cd "$launcher/src-tauri/gen/apple" &&
 xcodebuild -project bloodborne-launcher.xcodeproj -scheme bloodborne-launcher_iOS -configuration "$config" \
    -destination "id=$BB_IOS_DEVICE" -derivedDataPath "$out/xcode" -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$BB_IOS_TEAM" OTHER_LDFLAGS="\$(inherited) ${libs[*]} ${frameworks[*]} -lc++ -lz -lbz2 -liconv" \
    build 2>&1) | grep -E "error:|Undefined symbols|^  \"_|BUILD (SUCCEEDED|FAILED)" | head -40
app=$out/xcode/Build/Products/$config-iphoneos/Bloodborne.app
# The player's own recompiled library (scripts/ios/recomp.sh), when built; without it the game's
# code is interpreted. Added after Xcode signed the app, so both are signed again.
if [[ -f runtime/out/ios/librecomp.dylib ]]; then
    identity=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
    mkdir -p "$app/Frameworks"
    cp -f runtime/out/ios/librecomp.dylib "$app/Frameworks/"
    codesign --force --sign "$identity" "$app/Frameworks/librecomp.dylib"
    codesign --force --sign "$identity" --preserve-metadata=identifier,entitlements,requirements "$app"
fi
xcrun devicectl device install app --device "$BB_IOS_DEVICE" "$app" 2>&1 | grep -E "App installed|rror"
