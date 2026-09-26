#!/bin/bash
# HumTune DMG 打包：生成带 Applications 快捷方式的安装镜像
set -e
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$(dirname "$0")"

APP="build/HumTune.app"
DMG="build/HumTune-0.1.0.dmg"
STAGE="build/dmg_stage"

echo "=== 1. 确保 app 已打包 ==="
if [ ! -d "$APP" ]; then
  ./build.sh
fi

echo "=== 2. 准备 staging 目录 ==="
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
# 创建 Applications 软链
ln -s /Applications "$STAGE/Applications"

echo "=== 3. 生成 DMG ==="
rm -f "$DMG"
hdiutil create -volname "HumTune" -srcfolder "$STAGE" -ov -format UDZO "$DMG" 2>&1 | tail -5

echo ""
echo "=== 4. 验证 DMG ==="
hdiutil verify "$DMG" 2>&1 | tail -3
echo ""
echo "✅ DMG 生成: $DMG"
du -sh "$DMG"