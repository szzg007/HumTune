#!/bin/bash
# HumTune 打包脚本：把 release 二进制打包成 .app bundle（含麦克风权限 Info.plist）
set -e

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")"

APP_NAME="HumTune"
APP_BUNDLE="build/HumTune.app"
BIN=".build/release/HumTune"

echo "=== 1. 构建 release ==="
swift build -c release

echo "=== 2. 清理并创建 .app bundle ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "=== 3. 复制二进制 ==="
cp "$BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "=== 4. 复制 Info.plist ==="
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

echo "=== 5. ad-hoc 签名（本地可运行）==="
codesign --force --deep --sign - "$APP_BUNDLE" 2>&1 || echo "  (签名警告可忽略)"

echo ""
echo "✅ 打包完成: $APP_BUNDLE"
echo "运行: open $APP_BUNDLE"
echo ""
du -sh "$APP_BUNDLE"