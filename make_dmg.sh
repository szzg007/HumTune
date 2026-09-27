#!/bin/bash
# 打包 DMG 安装包（含 Applications 快捷方式）
set -e

cd "$(dirname "$0")"

APP_NAME="HumTune"
APP_PATH="build/${APP_NAME}.app"
DMG_NAME="哼曲HumTune-安装包.dmg"
STAGE_DIR="/tmp/humtune_dmg_stage"

# 清理
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
rm -f "$DMG_NAME"

# 复制 app + Applications 软链
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

# 制作 DMG
hdiutil create -volname "哼曲 HumTune" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_NAME" >/dev/null 2>&1

echo "✅ DMG 打包完成：$DMG_NAME"
ls -lh "$DMG_NAME"