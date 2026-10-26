#!/bin/bash
set -e
source /home/hardstone/Configs/dev/env.sh
export GRADLE_USER_HOME="$HOME/.gradle"
cd /home/hardstone/build_app

echo "=== 1. Syncing project to build_app ==="
rsync -av --delete --exclude '.dart_tool' --exclude 'build' --exclude '.git' /home/hardstone/Share/Common/CodeSpace/KairosStep/app/ /home/hardstone/build_app/

echo "=== 2. Building Release APKs (split-per-abi) ==="
flutter build apk --release --split-per-abi

echo "=== 3. Copying APKs to Share directory ==="
mkdir -p /home/hardstone/Share/Common/CodeSpace/KairosStep/app/build/app/outputs/flutter-apk/
cp -vf /home/hardstone/build_app/build/app/outputs/flutter-apk/*.apk /home/hardstone/Share/Common/CodeSpace/KairosStep/app/build/app/outputs/flutter-apk/

echo "=== 4. Final APK listing ==="
ls -lh /home/hardstone/Share/Common/CodeSpace/KairosStep/app/build/app/outputs/flutter-apk/*.apk
echo "=== RELEASE BUILD COMPLETE ==="
