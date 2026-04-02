#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BRIDGE_DIR="$PROJECT_ROOT/Cloude/CloudeAndroidBridge"
JNILIBS_DIR="$SCRIPT_DIR/app/src/main/jniLibs/arm64-v8a"
SWIFT_SDK_NAME="aarch64-unknown-linux-android28"

SWIFT_SDK_ROOT="$HOME/Library/org.swift.swiftpm/swift-sdks/swift-6.3-RELEASE_android.artifactbundle/swift-android"
SWIFT_STATIC_LIB_DIR="$SWIFT_SDK_ROOT/swift-resources/usr/lib/swift_static-aarch64/android"
SWIFT_SHARED_LIB_DIR="$SWIFT_SDK_ROOT/swift-resources/usr/lib/swift-aarch64/android"

. "${SWIFTLY_HOME_DIR:-$HOME/.swiftly}/env.sh"

echo "Building CloudeAndroidBridge for $SWIFT_SDK_NAME..."
cd "$BRIDGE_DIR"
swift build -c release --swift-sdk "$SWIFT_SDK_NAME" --static-swift-stdlib -Xlinker "-L$SWIFT_STATIC_LIB_DIR"

echo "Copying libraries to jniLibs..."
rm -rf "$JNILIBS_DIR"
mkdir -p "$JNILIBS_DIR"

cp "$BRIDGE_DIR/.build/$SWIFT_SDK_NAME/release/libCloudeAndroidBridge.so" "$JNILIBS_DIR/"

RUNTIME_LIBS=(
    libswiftCore.so
    libswift_Concurrency.so
    libswift_StringProcessing.so
    libswift_RegexParser.so
    libswift_Builtin_float.so
    libswift_math.so
    libswiftSynchronization.so
    libswiftSwiftOnoneSupport.so
    libswiftAndroid.so
    libBlocksRuntime.so
    libdispatch.so
    libswiftDispatch.so
    lib_FoundationICU.so
    libFoundation.so
    libFoundationEssentials.so
    libFoundationInternationalization.so
    libswiftObservation.so
)

for lib in "${RUNTIME_LIBS[@]}"; do
    if [ -f "$SWIFT_SHARED_LIB_DIR/$lib" ]; then
        cp "$SWIFT_SHARED_LIB_DIR/$lib" "$JNILIBS_DIR/"
    else
        echo "Warning: $lib not found, skipping"
    fi
done

NDK_HOME="${ANDROID_NDK_HOME:-$HOME/Library/Android/sdk/ndk/28.2.13676358}"
STRIP="$NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-strip"
LIBC_SHARED="$NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"
if [ -f "$LIBC_SHARED" ]; then
    cp "$LIBC_SHARED" "$JNILIBS_DIR/"
fi

echo "Stripping symbols..."
for so in "$JNILIBS_DIR"/*.so; do
    "$STRIP" "$so" 2>/dev/null || true
done

echo ""
echo "Done. Libraries in $JNILIBS_DIR:"
ls -lhS "$JNILIBS_DIR/"
echo ""
echo "Total size: $(du -sh "$JNILIBS_DIR" | cut -f1)"
