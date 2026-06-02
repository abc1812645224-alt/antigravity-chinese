#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

printf '\nClaude 桌面端汉化一键补丁\n'
printf '目录: %s\n\n' "$SCRIPT_DIR"

if [ ! -f "$SCRIPT_DIR/patch-desktop.sh" ]; then
  printf '错误: 找不到 patch-desktop.sh\n' >&2
  printf '\n按任意键关闭窗口...'
  read -r -n 1 _
  exit 1
fi

chmod +x "$SCRIPT_DIR/patch-desktop.sh"
"$SCRIPT_DIR/patch-desktop.sh"

printf '\n完成！请完全退出并重新打开 Claude 查看汉化效果。\n'
printf '恢复官方未修改版本可运行: ./patch-desktop.sh --restore\n'
printf '\n按任意键关闭窗口...'
read -r -n 1 _

