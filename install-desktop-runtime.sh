#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
PLIST_NAME="com.a1412.claude.zhpatch.plist"
SRC_PLIST="$ROOT/launchagents/$PLIST_NAME"
DEST_PLIST="$HOME/Library/LaunchAgents/$PLIST_NAME"
NODE_BIN="$(command -v node || true)"
APP_PATH="${CLAUDE_ZH_APP_PATH:-/Applications/Claude.app}"

if [[ -z "$NODE_BIN" ]]; then
  echo "未找到 Node.js。请先安装 Node.js 22 或更高版本，然后重新运行。"
  exit 1
fi

NODE_MAJOR="$("$NODE_BIN" -p "process.versions.node.split('.')[0]")"
if [[ "$NODE_MAJOR" -lt 22 ]]; then
  echo "当前 Node.js 版本过低: $("$NODE_BIN" --version)。请使用 Node.js 22 或更高版本。"
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "找不到 Claude.app: $APP_PATH"
  echo "如果 Claude 不在 /Applications，请这样指定："
  echo "CLAUDE_ZH_APP_PATH=\"/path/to/Claude.app\" ./install-desktop-runtime.sh"
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents" "$ROOT/logs"
chmod +x "$ROOT/bin/claude-desktop-zh-patch.js"

sed \
  -e "s#__NODE_BIN__#$NODE_BIN#g" \
  -e "s#__PATCH_SCRIPT__#$ROOT/bin/claude-desktop-zh-patch.js#g" \
  -e "s#__LOG_DIR__#$ROOT/logs#g" \
  "$SRC_PLIST" > "$DEST_PLIST"

plutil -lint "$DEST_PLIST"

launchctl bootout "gui/$(id -u)" "$DEST_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DEST_PLIST"
launchctl enable "gui/$(id -u)/com.a1412.claude.zhpatch"
launchctl kickstart -k "gui/$(id -u)/com.a1412.claude.zhpatch"

echo "Claude 桌面端不拆包汉化守护脚本已安装。"
echo "如果 Claude 已打开，脚本会重启它一次以启用本地调试注入。"
