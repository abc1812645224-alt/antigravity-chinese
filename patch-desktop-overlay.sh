#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${CLAUDE_APP_PATH:-/Applications/Claude.app}"
ACTION="patch"

usage() {
  cat <<'EOF'
Claude Desktop overlay 汉化补丁

用法:
  ./patch-desktop-overlay.sh            给 Claude 前端 bundle 注入汉化 overlay
  ./patch-desktop-overlay.sh --restore  恢复注入前的备份
  ./patch-desktop-overlay.sh --app PATH 指定 Claude.app 路径

说明:
  这个脚本会修改 Claude.app/Contents/Resources/ion-dist/assets/index-*.js。
  首次修改前会创建 *.claude-zh-overlay-backup 备份。
EOF
}

die() {
  printf '[claude-desktop-zh] 错误: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[claude-desktop-zh] %s\n' "$*"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app)
      shift
      [ "$#" -gt 0 ] || die "--app 需要一个 Claude.app 路径"
      APP_PATH="$1"
      ;;
    --restore)
      ACTION="restore"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "未知参数: $1"
      ;;
  esac
  shift
done

[ -d "$APP_PATH" ] || die "找不到 Claude.app: $APP_PATH"

ASSET_DIR="$APP_PATH/Contents/Resources/ion-dist/assets"
[ -d "$ASSET_DIR" ] || die "找不到资源目录: $ASSET_DIR"

find_index_bundle() {
  local file
  file="$(grep -RIl "Let's knock something off your list" "$ASSET_DIR" --include='*.js' 2>/dev/null | head -n 1 || true)"
  if [ -n "$file" ]; then
    printf '%s\n' "$file"
    return
  fi
  find "$ASSET_DIR" -type f -name 'index-*.js' -print | head -n 1
}

quit_claude() {
  if pgrep -x "Claude" >/dev/null 2>&1; then
    log "正在退出 Claude..."
    osascript -e 'tell application "Claude" to quit' >/dev/null 2>&1 || true
    sleep 2
    pkill -x Claude >/dev/null 2>&1 || true
    sleep 1
  fi
}

restore() {
  local file
  local restored=0
  while IFS= read -r file; do
    [ -f "$file.claude-zh-overlay-backup" ] || continue
    cp "$file.claude-zh-overlay-backup" "$file"
    log "已恢复: $file"
    restored=$((restored + 1))
  done < <(find "$ASSET_DIR" -type f -name '*.js' -print)
  [ "$restored" -gt 0 ] || log "没有找到 overlay 备份。"
}

patch() {
  local file
  file="$(find_index_bundle)"
  [ -n "$file" ] || die "找不到 index-*.js"

  if grep -q "__claudeDesktopZhBundleOverlay" "$file"; then
    log "已安装 overlay: $file"
    return
  fi

  [ -w "$file" ] || die "没有写入权限: $file"

  if [ ! -f "$file.claude-zh-overlay-backup" ]; then
    cp "$file" "$file.claude-zh-overlay-backup"
    log "已备份: $file.claude-zh-overlay-backup"
  fi

  python3 - "$file" <<'PY'
import sys

path = sys.argv[1]
overlay = r'''

;(() => {
  if (globalThis.__claudeDesktopZhBundleOverlay === 2) return;
  globalThis.__claudeDesktopZhBundleOverlay = 2;

  const phrases = new Map([
    ['Cowork', '协作'],
    ['Code', '代码'],
    ['New task', '新任务'],
    ['Projects', '项目'],
    ['Scheduled', '计划任务'],
    ['Live artifacts', '实时作品'],
    ['Customize', '自定义'],
    ['Recents', '最近'],
    ['General chat', '普通聊天'],
    ['Untitled', '未命名'],
    ['Gateway', '网关'],
    ["You're using Gateway", '你正在使用网关'],
    ['Add MCP servers, set a model allowlist, or change providers any time in the Inference configuration menu.', '你可以随时在推理配置菜单中添加 MCP 服务器、设置模型白名单或更换提供商。'],
    ['Inference configuration menu', '推理配置菜单'],
    ["Let's knock something off your list", '让我们完成清单上的事项'],
    ['Learn how to use Cowork safely.', '了解如何安全使用协作功能。'],
    ['Learn how to use Cowork safely', '了解如何安全使用协作功能'],
    ['How can I help you today?', '今天我能帮你做什么？'],
    ['Work in a project', '在项目中工作'],
    ['Active', '进行中'],
    ['Clear active', '清除进行中'],
    ['Open', '打开'],
    ['Search', '搜索'],
    ['Settings', '设置'],
    ['Help', '帮助'],
    ['New chat', '新聊天'],
    ['Message Claude', '给 Claude 发送消息'],
    ['Add files', '添加文件'],
    ['Today', '今天'],
    ['Yesterday', '昨天'],
    ['Older', '更早'],
    ['View all', '查看全部'],
    ['Loading...', '加载中...'],
    ['Loading', '加载中'],
    ['Cancel', '取消'],
    ['Continue', '继续'],
    ['Save', '保存'],
    ['Delete', '删除'],
    ['Edit', '编辑'],
    ['Copy', '复制'],
    ['Done', '完成'],
    ['Retry', '重试'],
    ['Try again', '重试'],
    ['Allow', '允许'],
    ['Deny', '拒绝'],
    ['Accept', '接受'],
    ['Reject', '拒绝'],
    ['Close', '关闭'],
    ['Back', '返回'],
    ['Next', '下一步'],
    ['Error', '错误'],
    ['Warning', '警告'],
    ['Success', '成功'],
    ['Failed', '失败'],
  ]);

  const patterns = [
    [/(^|\s)(\d+)\s+days?\s+ago/g, '$1$2 天前'],
    [/(^|\s)(\d+)\s+hours?\s+ago/g, '$1$2 小时前'],
    [/(^|\s)(\d+)\s+minutes?\s+ago/g, '$1$2 分钟前'],
    [/(^|\s)(\d+)\s+seconds?\s+ago/g, '$1$2 秒前'],
    [/just now/gi, '刚刚'],
    [/See all \((\d+)\)/g, '查看全部 ($1)'],
  ];

  function escapeRegExp(value) {
    return value.replace(/[|\\{}()[\]^$+*?.]/g, '\\$&');
  }

  function replacePhrase(value, source, target) {
    const escaped = escapeRegExp(source);
    const startsWord = /^[A-Za-z0-9]/.test(source);
    const endsWord = /[A-Za-z0-9]$/.test(source);
    const pattern = new RegExp((startsWord ? '(?<![A-Za-z0-9])' : '') + escaped + (endsWord ? '(?![A-Za-z0-9])' : ''), 'g');
    return value.replace(pattern, target);
  }

  function translate(value) {
    if (!value || !/[A-Za-z]/.test(value)) return value;
    let next = value;
    const sorted = [...phrases].sort((a, b) => b[0].length - a[0].length);
    for (const [source, target] of sorted) next = replacePhrase(next, source, target);
    for (const [pattern, target] of patterns) next = next.replace(pattern, target);
    return next;
  }

  function shouldSkip(node) {
    const element = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
    return !!element?.closest?.('script, style, textarea, code, pre, .xterm, .monaco-editor');
  }

  function translateElement(element) {
    for (const attr of ['aria-label', 'title', 'placeholder', 'alt', 'data-tooltip-content']) {
      const value = element.getAttribute?.(attr);
      if (!value) continue;
      const translated = translate(value);
      if (translated !== value) element.setAttribute(attr, translated);
    }
  }

  function translateNode(root) {
    if (!root || shouldSkip(root)) return;
    if (root.nodeType === Node.TEXT_NODE) {
      const translated = translate(root.nodeValue || '');
      if (translated !== root.nodeValue) root.nodeValue = translated;
      return;
    }
    if (root.nodeType !== Node.ELEMENT_NODE && root.nodeType !== Node.DOCUMENT_NODE) return;
    if (root.nodeType === Node.ELEMENT_NODE) translateElement(root);
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (shouldSkip(node)) continue;
      if (node.nodeType === Node.TEXT_NODE) {
        const translated = translate(node.nodeValue || '');
        if (translated !== node.nodeValue) node.nodeValue = translated;
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        translateElement(node);
      }
    }
  }

  function run() {
    document.documentElement.lang = 'zh-CN';
    translateNode(document);
    new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === 'characterData') {
          translateNode(mutation.target);
        } else if (mutation.type === 'attributes') {
          translateElement(mutation.target);
        } else {
          for (const node of mutation.addedNodes) translateNode(node);
        }
      }
    }).observe(document.documentElement, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ['aria-label', 'title', 'placeholder', 'alt', 'data-tooltip-content'],
    });
  }

  if (typeof document === 'undefined') return;
  if (document.readyState === 'loading') {
    window.addEventListener('DOMContentLoaded', run, { once: true });
  } else {
    run();
  }
})();
'''

with open(path, 'a', encoding='utf-8') as fh:
    fh.write(overlay)
PY

  log "已安装 overlay: $file"
}

quit_claude
if [ "$ACTION" = "restore" ]; then
  restore
else
  patch
fi
log "完成。正在重新打开 Claude..."
open "$APP_PATH"
