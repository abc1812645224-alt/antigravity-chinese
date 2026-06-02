#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
PLIST_NAME="com.a1412.claude.zhpatch.plist"
DEST_PLIST="$HOME/Library/LaunchAgents/$PLIST_NAME"

launchctl bootout "gui/$(id -u)" "$DEST_PLIST" 2>/dev/null || true
rm -f "$DEST_PLIST"

echo "Claude 桌面端不拆包汉化守护脚本已卸载。"
echo "已注入到当前窗口的汉化会在重启 Claude 后消失。"
