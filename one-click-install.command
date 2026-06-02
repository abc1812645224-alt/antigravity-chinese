#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

printf '\nClaude Code 汉化一键安装\n'
printf '目录: %s\n\n' "$SCRIPT_DIR"

if [ ! -f "$SCRIPT_DIR/install.sh" ]; then
  printf '错误: 找不到 install.sh\n' >&2
  printf '\n按任意键关闭窗口...'
  read -r -n 1 _
  exit 1
fi

chmod +x "$SCRIPT_DIR/install.sh"
"$SCRIPT_DIR/install.sh"

printf '\n安装流程已结束。\n'
printf '请重新打开一个终端，然后运行: claude-zh\n'
printf '如果默认 shadow 模式已启用，也可以直接运行: claude\n'
printf '\n按任意键关闭窗口...'
read -r -n 1 _
