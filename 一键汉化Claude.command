#!/bin/bash

# 获取脚本所在目录并切换过去
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR" || { echo "无法切换到工作目录！"; sleep 5; exit 1; }

echo "======================================"
echo "    正在启动 Claude 一键完美汉化"
echo "======================================"
echo ""

# 关闭可能正在运行的 Claude
pkill -9 -f "Claude" 2>/dev/null
echo "已关闭后台残留的 Claude 进程..."
sleep 1

# 执行核心汉化脚本
if [ -f "./patch-desktop.sh" ]; then
    ./patch-desktop.sh
else
    echo "错误：核心汉化脚本 patch-desktop.sh 丢失！"
fi

echo ""
echo "======================================"
echo "    汉化流程结束，正在自动启动 Claude"
echo "======================================"

# 重新启动 Claude
open -a /Applications/Claude.app 2>/dev/null

echo ""
echo "5秒后自动关闭此窗口..."
sleep 5
