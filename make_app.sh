#!/bin/bash
# 构建 .app bundle（带麦克风权限声明）
set -e

cd "$(dirname "$0")"

APP_NAME="HumTune"
APP_DIR="build/${APP_NAME}.app"
BIN=".build/release/HumTuneApp"

# 清理旧 app
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 复制可执行文件
cp "$BIN" "$APP_DIR/Contents/MacOS/HumTuneApp"

# 复制 Info.plist
cp Info.plist "$APP_DIR/Contents/Info.plist"

# ad-hoc 签名（本地可跑，分发需 Developer ID）
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "⚠️ ad-hoc 签名失败（可忽略，本地仍可跑）"

echo "✅ .app 构建完成：$APP_DIR"
du -sh "$APP_DIR"