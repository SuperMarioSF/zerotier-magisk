#!/usr/bin/env bash
# 构建 zerotier-magisk 控制器 App（增强节点页版）
#
# 用法:
#   直连:   ./build-apk.sh
#   走代理: LAN_PROXY=http://proxy-host:port ./build-apk.sh
# 产物: app/build/app/outputs/flutter-apk/app-release.apk
#
# 环境要求（构建机需自行装好）:
#   - Flutter SDK: ~/flutter （3.47.2 stable）
#   - Android SDK: ~/Android/Sdk （platforms;android-36 + build-tools;36.0.0）
#   - JDK 21: /usr/bin/java
# 依赖下载可能需要代理（GitHub / pub.dev / storage.googleapis.com / dl.google.com）:
# 可直接 export LAN_PROXY 后用本脚本，或在 ~/.gradle/gradle.properties 配好 systemProp。
set -euo pipefail

if [ -n "${LAN_PROXY:-}" ]; then
  echo "== 使用代理: $LAN_PROXY =="
  export http_proxy="$LAN_PROXY" https_proxy="$LAN_PROXY" HTTP_PROXY="$LAN_PROXY" HTTPS_PROXY="$LAN_PROXY"
  # Gradle 是 JVM 程序，不读 http_proxy 环境变量，必须走 systemProp
  _proxy_host=${LAN_PROXY#*://}; _proxy_host=${_proxy_host%:*}
  _proxy_port=${LAN_PROXY##*:}
  export GRADLE_OPTS="-Dhttp.proxyHost=$_proxy_host -Dhttp.proxyPort=$_proxy_port -Dhttps.proxyHost=$_proxy_host -Dhttps.proxyPort=$_proxy_port"
fi

export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$HOME/flutter/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

cd "$(dirname "$0")/app"

echo "== flutter --version =="
flutter --version

echo "== pub get =="
flutter pub get

echo "== gen-l10n =="
flutter gen-l10n

echo "== build apk =="
flutter build apk --release ${TARGET_PLATFORM:+--target-platform "$TARGET_PLATFORM"}

ls -la build/app/outputs/flutter-apk/app-release.apk
