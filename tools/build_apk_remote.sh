#!/usr/bin/env bash
# KairosStep Android APK 构建脚本（增量优先，避免每次全量重编）
#
# 用法：
#   tools/build_apk_remote.sh              增量构建（默认，日常打包用这个）
#   tools/build_apk_remote.sh --clean      全量重建（代码未变也强制重编）
#   tools/build_apk_remote.sh --no-sync    跳过源码同步（只重跑打包）
#   tools/build_apk_remote.sh --minify     开启 R8 混淆/瘦身（默认关闭求快）
#
# 速度要点：
#   1. 在本地磁盘 $KAIROS_BUILD_DIR（默认 /home/hardstone/build_app）构建，
#      不在 vmhgfs 共享盘上跑 Gradle。
#   2. 同步时保留 build/、.dart_tool/、android/.gradle/ 增量缓存，只传变更文件。
#   3. 复用环境里的 GRADLE_USER_HOME（默认 ~/.cache/gradle），单 daemon + 本地构建缓存。
#   4. pubspec 未变化时用 --no-pub 跳过依赖解析。
#   5. 只打 arm64、关闭 R8/lint/原生符号表，稳定态增量构建可控制在 1 分钟内。
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_DIR/app"
BUILD_DIR="${KAIROS_BUILD_DIR:-/home/hardstone/build_app}"
OUT_DIR="$REPO_DIR/output/mobile"

CLEAN=0
DO_SYNC=1
MINIFY=0
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --no-sync) DO_SYNC=0 ;;
    --minify) MINIFY=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "未知参数：$arg（可用：--clean / --no-sync / --minify）" >&2; exit 2 ;;
  esac
done
# 通过 Gradle 项目属性控制 R8；默认关闭以换取打包速度。
export ORG_GRADLE_PROJECT_kairosMinify=$([ "$MINIFY" = 1 ] && echo true || echo false)

if [ -f /home/hardstone/Configs/dev/env.sh ]; then
  # shellcheck disable=SC1091
  source /home/hardstone/Configs/dev/env.sh
fi
# 不要强制改回 ~/.gradle：环境里已有 ~/.cache/gradle 的完整依赖缓存，
# 两套 gradle home 会各自拉起一个 8G daemon，直接把内存打爆。
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/.cache/gradle}"

T0=$(date +%s)
phase() {
  echo
  echo "=== $1 ==="
  echo "    (+$(( $(date +%s) - T0 ))s)"
}

AVAIL_MB=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
if [ "$AVAIL_MB" -lt 3000 ]; then
  echo "⚠️  可用内存仅 ${AVAIL_MB}MB，构建可能因 swap 变慢。"
  echo "   可先执行：pkill -f GradleDaemon; pkill -f KotlinCompileDaemon"
fi

# ---------- 版本号 ----------
VERSION_RAW=$(awk '/^version:/{print $2; exit}' "$SRC_DIR/pubspec.yaml")
if [ -z "${VERSION_RAW:-}" ]; then
  echo "无法从 pubspec.yaml 读取版本号" >&2
  exit 1
fi
VERSION_NAME="${VERSION_RAW%%+*}"
BUILD_NUMBER="${VERSION_RAW##*+}"
[ "$BUILD_NUMBER" = "$VERSION_RAW" ] && BUILD_NUMBER=0
STAMP=$(date +%m%d-%H%M%S)
APK_NAME="KairosStep-${VERSION_NAME}+${BUILD_NUMBER}-${STAMP}-arm64-v8a.apk"
COMMIT=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)

echo "构建版本：$VERSION_NAME (build $BUILD_NUMBER)  commit $COMMIT"
echo "构建目录：$BUILD_DIR"
echo "Gradle 缓存：$GRADLE_USER_HOME"

# ---------- 1. 全量重建（可选） ----------
if [ "$CLEAN" = 1 ]; then
  phase "1/4 清理构建产物（保留 Gradle 依赖缓存）"
  rm -rf "$BUILD_DIR/build" "$BUILD_DIR/.dart_tool"
fi

# ---------- 2. 增量同步 ----------
if [ "$DO_SYNC" = 1 ]; then
  phase "2/4 增量同步源码到本地构建目录"
  mkdir -p "$BUILD_DIR"
  rsync -a --delete \
    --exclude='.git' \
    --exclude='.dart_tool' \
    --exclude='build' \
    --exclude='android/.gradle' \
    --exclude='android/.kotlin' \
    --exclude='android/build' \
    --exclude='android/app/build' \
    --exclude='android/local.properties' \
    --exclude='.flutter-plugins-dependencies' \
    --exclude='*.log' \
    "$SRC_DIR/" "$BUILD_DIR/"
else
  phase "2/4 跳过源码同步（--no-sync）"
fi
[ -f "$BUILD_DIR/android/local.properties" ] || \
  cp "$SRC_DIR/android/local.properties" "$BUILD_DIR/android/local.properties"

# ---------- 3. 依赖 + 编译 ----------
phase "3/4 依赖检查并构建 Release APK"
PUB_ARGS=("--no-pub")
PKG_CONFIG="$BUILD_DIR/.dart_tool/package_config.json"
PUB_STAMP="$BUILD_DIR/.dart_tool/.kairos_pubspec_hash"
PUB_HASH=$(cat "$SRC_DIR/pubspec.yaml" "$SRC_DIR/pubspec.lock" 2>/dev/null | sha256sum | awk '{print $1}')
if [ ! -f "$PKG_CONFIG" ] || [ "$(cat "$PUB_STAMP" 2>/dev/null || true)" != "$PUB_HASH" ]; then
  echo "pubspec 有变化，执行 flutter pub get ..."
  ( cd "$BUILD_DIR" && flutter pub get )
  printf '%s\n' "$PUB_HASH" > "$PUB_STAMP"
  PUB_ARGS=()
fi
( cd "$BUILD_DIR" && flutter build apk --release --target-platform android-arm64 "${PUB_ARGS[@]}" )

# ---------- 4. 归档 ----------
phase "4/4 校验并归档 APK"
RELEASE_APK="$BUILD_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$RELEASE_APK" ]; then
  echo "未找到构建产物：$RELEASE_APK" >&2
  exit 1
fi

# 从 local.properties 找 SDK，用 aapt 校验 APK 里真实的 versionName/versionCode
SDK_DIR=$(awk -F= '/^sdk.dir=/{print $2; exit}' "$BUILD_DIR/android/local.properties")
AAPT=$(ls -d "$SDK_DIR"/build-tools/*/aapt 2>/dev/null | sort -V | tail -1 || true)
if [ -n "${AAPT:-}" ]; then
  BADGING=$("$AAPT" dump badging "$RELEASE_APK" 2>/dev/null | sed -n '1p')
  echo "APK 校验：$BADGING"
  case "$BADGING" in
    *"versionName='$VERSION_NAME'"*"versionCode='$BUILD_NUMBER'"*|\
    *"versionCode='$BUILD_NUMBER'"*"versionName='$VERSION_NAME'"*) ;;
    *) echo "⚠️  APK 内版本号与 pubspec 不一致，请检查 pubspec.yaml / local.properties" >&2 ;;
  esac
fi

mkdir -p "$OUT_DIR"
# 先写临时文件再原子替换，构建失败时不会留下半个包
cp -f "$RELEASE_APK" "$OUT_DIR/.$APK_NAME.tmp"
mv -f "$OUT_DIR/.$APK_NAME.tmp" "$OUT_DIR/$APK_NAME"
( cd "$OUT_DIR" && sha256sum "$APK_NAME" > "$APK_NAME.sha256" )
# vmhgfs 共享盘不支持软链，改用一个纯文本指针文件标识最新包。
printf '%s\n' "$APK_NAME" > "$OUT_DIR/KairosStep-latest.txt"

# 可选的 R8 mapping（开启 minify 时才有）
MAPPING_TXT="$BUILD_DIR/build/app/outputs/mapping/release/mapping.txt"
if [ -f "$MAPPING_TXT" ]; then
  cp -f "$MAPPING_TXT" "$OUT_DIR/${APK_NAME%.apk}.mapping.txt"
fi

SHA256=$(awk '{print $1}' "$OUT_DIR/$APK_NAME.sha256")
cat > "$OUT_DIR/BUILD_INFO.txt" <<EOF
versionName: $VERSION_NAME
versionCode: $BUILD_NUMBER
commit: $COMMIT
builtAt: $(date '+%Y-%m-%d %H:%M:%S')
apk: $APK_NAME
sha256: $SHA256
EOF

echo
ls -lh "$OUT_DIR/$APK_NAME"
echo "→ $OUT_DIR/$APK_NAME"
echo "→ 最新包记录：$OUT_DIR/KairosStep-latest.txt"
echo "总耗时：$(( $(date +%s) - T0 ))s"
