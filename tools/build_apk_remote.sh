#!/bin/bash
set -e
if [ -f /home/hardstone/Configs/dev/env.sh ]; then
    source /home/hardstone/Configs/dev/env.sh
fi
export GRADLE_USER_HOME="$HOME/.gradle"

SHARE_DIR="/home/hardstone/Share/Common/CodeSpace/KairosStep"
SHARE_OUTPUT_DIR="$SHARE_DIR/app/build/app/outputs/flutter-apk"
BUILD_DIR="/home/hardstone/build_app"
BUILD_OUTPUT_DIR="$BUILD_DIR/build/app/outputs/flutter-apk"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== 1. Syncing project to build_app ==="
rsync -av --delete --exclude '.dart_tool' --exclude 'build' --exclude '.git' "$SHARE_DIR/app/" "$BUILD_DIR/"

echo "=== 2. Cleaning old build artifacts ==="
rm -vf "$BUILD_OUTPUT_DIR"/*.apk* 2>/dev/null || true
rm -vf "$BUILD_DIR/build/app/outputs/apk/release"/*.apk 2>/dev/null || true
rm -vf "$SHARE_OUTPUT_DIR"/*.apk* 2>/dev/null || true

# Extract version from pubspec.yaml (e.g. 1.0.0+1 -> 1.0.0)
VERSION=$(grep -E '^version:' "$BUILD_DIR/pubspec.yaml" | sed -E 's/version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
if [ -z "$VERSION" ]; then
    VERSION="1.0.0"
fi
APP_NAME="KairosStep"
TARGET_APK_NAME="${APP_NAME}-${VERSION}.apk"

# 四段式多级版本号与时间戳标识 (vMAJOR.FEATURE.PATCH.MMddHHmmss+apk)
TIMESTAMP=$(date +"%m%d%H%M%S")
TIMESTAMP_VERSION="v${VERSION}.${TIMESTAMP}+apk"
TIMESTAMP_APK_NAME="${APP_NAME}-${TIMESTAMP_VERSION}.apk"

echo "=== 3. Building Release APK (Version: $VERSION / $TIMESTAMP_VERSION) ==="
flutter build apk --release --target-platform android-arm64

echo "=== 4. Packaging and Renaming APK ==="
mkdir -p "$SHARE_OUTPUT_DIR"
OUTPUT_MOBILE_DIR="$SHARE_DIR/output/mobile"
mkdir -p "$OUTPUT_MOBILE_DIR"

RELEASE_APK="$BUILD_OUTPUT_DIR/app-release.apk"
if [ ! -f "$RELEASE_APK" ]; then
    # Fallback to any apk generated if app-release.apk not directly found
    RELEASE_APK=$(ls "$BUILD_OUTPUT_DIR"/*.apk | head -n 1)
fi

echo "Source APK: $RELEASE_APK"
echo "Target APK Name: $TARGET_APK_NAME"
echo "Timestamp APK Name: $TIMESTAMP_APK_NAME"

# Copy primary target APK
cp -vf "$RELEASE_APK" "$SHARE_OUTPUT_DIR/$TARGET_APK_NAME"
cp -vf "$RELEASE_APK" "$SHARE_OUTPUT_DIR/$TIMESTAMP_APK_NAME"

# Also provide kairo_step and 数字阶跃 named packages for complete compatibility
cp -vf "$SHARE_OUTPUT_DIR/$TARGET_APK_NAME" "$SHARE_OUTPUT_DIR/kairo_step-${VERSION}.apk"
cp -vf "$SHARE_OUTPUT_DIR/$TARGET_APK_NAME" "$SHARE_OUTPUT_DIR/数字阶跃-${VERSION}.apk"
cp -vf "$SHARE_OUTPUT_DIR/$TARGET_APK_NAME" "$SHARE_DIR/$TARGET_APK_NAME"

# Copy to output/mobile/ following multi-client convergence rules
cp -vf "$SHARE_OUTPUT_DIR/$TARGET_APK_NAME" "$OUTPUT_MOBILE_DIR/$TARGET_APK_NAME"
cp -vf "$SHARE_OUTPUT_DIR/$TARGET_APK_NAME" "$OUTPUT_MOBILE_DIR/$TIMESTAMP_APK_NAME"

# Copy mapping.txt / symbols if generated
MAPPING_TXT="$BUILD_DIR/build/app/outputs/mapping/release/mapping.txt"
if [ -f "$MAPPING_TXT" ]; then
    cp -vf "$MAPPING_TXT" "$OUTPUT_MOBILE_DIR/mapping-${TIMESTAMP_VERSION}.txt"
fi

# Generate sha256 checksums
cd "$SHARE_OUTPUT_DIR"
sha256sum "$TARGET_APK_NAME" > "${TARGET_APK_NAME}.sha256"
sha256sum "$TIMESTAMP_APK_NAME" > "${TIMESTAMP_APK_NAME}.sha256"

cd "$OUTPUT_MOBILE_DIR"
sha256sum "$TARGET_APK_NAME" > "${TARGET_APK_NAME}.sha256"
sha256sum "$TIMESTAMP_APK_NAME" > "${TIMESTAMP_APK_NAME}.sha256"

cd "$SHARE_DIR"
sha256sum "$TARGET_APK_NAME" > "${TARGET_APK_NAME}.sha256"

echo "=== 5. Final APK listing ==="
ls -lh "$SHARE_OUTPUT_DIR"/*.apk
ls -lh "$OUTPUT_MOBILE_DIR"/*.apk
ls -lh "$SHARE_DIR"/*.apk 2>/dev/null || true
echo "=== RELEASE BUILD AND PACKAGING COMPLETE ==="
