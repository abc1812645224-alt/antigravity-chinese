#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
PLIST_NAME="com.a1412.antigravity.zhpatch.plist"
SRC_PLIST="$ROOT/launchagents/$PLIST_NAME"
DEST_PLIST="$HOME/Library/LaunchAgents/$PLIST_NAME"
NODE_BIN="$(command -v node || true)"

if [[ -z "$NODE_BIN" ]]; then
  echo "未找到 Node.js。请先安装 Node.js 22 或更高版本，然后重新运行 install.sh。"
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents" "$ROOT/logs"
chmod +x "$ROOT/bin/antigravity-zh-patch.js"
sed \
  -e "s#__NODE_BIN__#$NODE_BIN#g" \
  -e "s#__PATCH_SCRIPT__#$ROOT/bin/antigravity-zh-patch.js#g" \
  -e "s#__LOG_DIR__#$ROOT/logs#g" \
  "$SRC_PLIST" > "$DEST_PLIST"
plutil -lint "$DEST_PLIST"

launchctl bootout "gui/$(id -u)" "$DEST_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DEST_PLIST"
launchctl enable "gui/$(id -u)/com.a1412.antigravity.zhpatch"
launchctl kickstart -k "gui/$(id -u)/com.a1412.antigravity.zhpatch"

echo "Antigravity 中文汉化脚本已安装并开始运行。"
