#!/bin/bash
# HumTune 开发环境引导：让 swift/xcodebuild/test 走 Xcode toolchain（而非默认的 CommandLineTools）
# 用法：source ./env.sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
echo "✅ DEVELOPER_DIR → $(xcode-select -p 2>/dev/null || echo $DEVELOPER_DIR)"
echo "✅ swift → $(swift --version 2>&1 | head -1)"
echo "✅ xcodebuild → $(xcodebuild -version 2>&1 | head -1)"