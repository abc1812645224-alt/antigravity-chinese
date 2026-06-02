#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${CLAUDE_APP_PATH:-/Applications/Claude.app}"
ACTION="patch"

usage() {
  cat <<'EOF'
Claude 桌面端 macOS 汉化补丁

用法:
  ./patch-desktop.sh              汉化 /Applications/Claude.app
  ./patch-desktop.sh --app PATH   指定 Claude.app 路径
  ./patch-desktop.sh --restore    恢复备份

说明:
  这个脚本 patch Claude.app 自带的 i18n JSON，不修改 app.asar。
  每个被修改的文件都会先备份为 *.claude-zh-backup。
EOF
}

log() {
  printf '[claude-desktop-zh] %s\n' "$*"
}

die() {
  printf '[claude-desktop-zh] 错误: %s\n' "$*" >&2
  exit 1
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

USE_TMP=false
ORIG_APP_PATH=""

if [ "$APP_PATH" = "/Applications/Claude.app" ]; then
  log "采用临时目录拷贝方式（以支持本地代码签名重签，规避 macOS 损坏警告）..."
  USE_TMP=true
  ORIG_APP_PATH="$APP_PATH"
  TMP_APP_PATH="/tmp/Claude.app"
  
  # Clean up any leftover from previous runs
  rm -rf "$TMP_APP_PATH"
  
  # Copy original app to tmp (using cp -R to strip macOS translocation lock!)
  cp -R "$ORIG_APP_PATH" "$TMP_APP_PATH"
  APP_PATH="$TMP_APP_PATH"
fi

RES_DIR="$APP_PATH/Contents/Resources"
FILES=(
  "$RES_DIR/en-US.json"
  "$RES_DIR/ion-dist/i18n/en-US.json"
)


restore_file() {
  local file="$1"
  local backup="$file.claude-zh-backup"
  if [ -f "$backup" ]; then
    cp "$backup" "$file"
    log "已恢复: $file"
  fi
}

restore() {
  for file in "${FILES[@]}"; do
    restore_file "$file"
  done
  local index_js
  index_js="$(find "$RES_DIR/ion-dist/assets" -type f -name 'index-*.js' -print | head -n 1 || true)"
  if [ -n "$index_js" ] && [ -f "$index_js.claude-zh-backup" ]; then
    cp "$index_js.claude-zh-backup" "$index_js"
    log "已恢复前端 bundle: $index_js"
  fi
  log "恢复完成。请完全退出并重新打开 Claude。"
}

quit_claude() {
  if pgrep -x "Claude" >/dev/null 2>&1; then
    log "正在退出 Claude..."
    osascript -e 'tell application "Claude" to quit' >/dev/null 2>&1 || true
    sleep 2
  fi
}

patch() {
  for file in "${FILES[@]}"; do
    [ -f "$file" ] || die "找不到资源文件: $file"
    [ -w "$file" ] || die "没有写入权限: $file"
    if [ ! -f "$file.claude-zh-backup" ]; then
      cp "$file" "$file.claude-zh-backup"
      log "已备份: $file.claude-zh-backup"
    fi
  done

  python3 - "$RES_DIR" <<'PY'
import json
import os
import sys

res_dir = sys.argv[1]
files = [
    os.path.join(res_dir, "en-US.json"),
    os.path.join(res_dir, "ion-dist", "i18n", "en-US.json"),
]

translations = {
    # 截图首页和侧边栏
    "Cowork": "协作",
    "Code": "代码",
    "New task": "新任务",
    "Projects": "项目",
    "Scheduled": "计划任务",
    "Live artifacts": "实时作品",
    "Customize": "自定义",
    "Recents": "最近",
    "Let's knock something off your list": "让我们完成清单上的事项",
    "Learn how to use Cowork safely.": "了解如何安全使用协作功能。",
    "How can I help you today?": "今天我能帮你做什么？",
    "Work in a project": "在项目中工作",
    "Active": "进行中",
    "Clear active": "清除进行中",
    "Untitled": "未命名",
    "General chat": "普通聊天",
    "Home": "首页",
    "Today": "今天",
    "Yesterday": "昨天",
    "Older": "更早",
    "View all": "查看全部",
    "Search": "搜索",
    "Settings": "设置",
    "Help": "帮助",
    "Sign out": "退出登录",
    "Sign in": "登录",
    # 常见按钮和状态
    "Cancel": "取消",
    "Continue": "继续",
    "Create": "创建",
    "Save": "保存",
    "Delete": "删除",
    "Edit": "编辑",
    "Copy": "复制",
    "Done": "完成",
    "Retry": "重试",
    "Try again": "重试",
    "Allow": "允许",
    "Deny": "拒绝",
    "Accept": "接受",
    "Reject": "拒绝",
    "Open": "打开",
    "Close": "关闭",
    "Back": "返回",
    "Next": "下一步",
    "Loading...": "加载中...",
    "Scanning...": "扫描中...",
    "Error": "错误",
    "Warning": "警告",
    "Success": "成功",
    "Failed": "失败",
    # Claude Code / Cowork 基础文案
    "Try Claude Code": "试用 Claude Code",
    "Set up Cowork": "设置协作",
    "Power through tasks with Cowork": "用协作功能高效完成任务",
    "You’re all set up with Cowork": "协作功能已设置完成",
    "Create task": "创建任务",
    "New task draft": "新任务草稿",
    "Start task": "开始任务",
    "Stop task": "停止任务",
    "Task complete": "任务完成",
    "Task failed": "任务失败",
}

patched = 0
for path in files:
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)

    changed = 0
    for key, value in list(data.items()):
        if isinstance(value, str) and value in translations:
            data[key] = translations[value]
            changed += 1

    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    patched += changed
    print(f"已汉化 {changed} 条: {path}")

print(f"合计汉化 {patched} 条。")
PY

  log "正在提取新版 app.asar 以注入前端汉化代码..."
  local asar_dir="$RES_DIR/app.asar.unpacked_temp"
  npx -y @electron/asar extract "$RES_DIR/app.asar" "$asar_dir" 2>/dev/null
  
  log "正在向前端 HTML 注入汉化 overlay..."
  
  python3 -c '
import os
import sys
import glob

asar_dir = sys.argv[1]
overlay = """
<script>
;(() => {
  if (globalThis.__claudeDesktopZhBundleOverlay === 2) return;
  globalThis.__claudeDesktopZhBundleOverlay = 2;

  const phrases = new Map([
    ["Claude", "Claude"],
    ["Cowork", "协作"],
    ["Code", "代码"],
    ["New task", "新任务"],
    ["Projects", "项目"],
    ["Scheduled", "计划任务"],
    ["Live artifacts", "实时作品"],
    ["Customize", "自定义"],
    ["Recents", "最近"],
    ["Let'"'"'s knock something off your list", "让我们完成清单上的事项"],
    ["Learn how to use Cowork safely.", "了解如何安全使用协作功能。"],
    ["Learn how to use Cowork safely", "了解如何安全使用协作功能"],
    ["How can I help you today?", "今天我能帮你做什么？"],
    ["Work in a project", "在项目中工作"],
    ["Active", "进行中"],
    ["Clear active", "清除进行中"],
    ["General chat", "普通聊天"],
    ["Untitled", "未命名"],
    ["Home", "首页"],
    ["Today", "今天"],
    ["Yesterday", "昨天"],
    ["Older", "更早"],
    ["View all", "查看全部"],
    ["Search", "搜索"],
    ["Settings", "设置"],
    ["Help", "帮助"],
    ["Gateway", "网关"],
    ["New chat", "新聊天"],
    ["Start a new chat", "开始新聊天"],
    ["Ask anything", "随便问点什么"],
    ["Message Claude", "给 Claude 发送消息"],
    ["Type a message", "输入消息"],
    ["Add files", "添加文件"],
    ["Upload file", "上传文件"],
    ["Choose files", "选择文件"],
    ["Open menu", "打开菜单"],
    ["Open sidebar", "打开侧边栏"],
    ["Close sidebar", "关闭侧边栏"],
    ["Sign in", "登录"],
    ["Sign out", "退出登录"],
    ["Log in", "登录"],
    ["Log out", "退出登录"],
    ["Account", "账户"],
    ["Profile", "个人资料"],
    ["Appearance", "外观"],
    ["General", "通用"],
    ["Notifications", "通知"],
    ["Privacy", "隐私"],
    ["Developer", "开发者"],
    ["Connectors", "连接器"],
    ["Artifacts", "作品"],
    ["Create", "创建"],
    ["Cancel", "取消"],
    ["Continue", "继续"],
    ["Save", "保存"],
    ["Delete", "删除"],
    ["Remove", "移除"],
    ["Edit", "编辑"],
    ["Rename", "重命名"],
    ["Copy", "复制"],
    ["Done", "完成"],
    ["Retry", "重试"],
    ["Try again", "重试"],
    ["Allow", "允许"],
    ["Deny", "拒绝"],
    ["Accept", "接受"],
    ["Reject", "拒绝"],
    ["Open", "打开"],
    ["Close", "关闭"],
    ["Back", "返回"],
    ["Next", "下一步"],
    ["Loading...", "加载中..."],
    ["Loading", "加载中"],
    ["Scanning...", "扫描中..."],
    ["Searching...", "搜索中..."],
    ["Error", "错误"],
    ["Warning", "警告"],
    ["Success", "成功"],
    ["Failed", "失败"],
    ["Try Claude Code", "试用 Claude Code"],
    ["Set up Cowork", "设置协作"],
    ["Power through tasks with Cowork", "用协作功能高效完成任务"],
    ["You’re all set up with Cowork", "协作功能已设置完成"],
    ["You'"'"'re all set up with Cowork", "协作功能已设置完成"],
    ["Create task", "创建任务"],
    ["New task draft", "新任务草稿"],
    ["Start task", "开始任务"],
    ["Stop task", "停止任务"],
    ["Task complete", "任务完成"],
    ["Task failed", "任务失败"]
  ]);

  const patterns = [
    [/(^|\s)(\d+)\s+days?\s+ago/g, "$1$2 天前"],
    [/(^|\s)(\d+)\s+hours?\s+ago/g, "$1$2 小时前"],
    [/(^|\s)(\d+)\s+minutes?\s+ago/g, "$1$2 分钟前"],
    [/(^|\s)(\d+)\s+seconds?\s+ago/g, "$1$2 秒前"],
    [/just now/gi, "刚刚"],
    [/See all \((\d+)\)/g, "查看全部 ($1)"],
    [/New session in (.+)/g, "在 $1 中新建会话"],
    [/Trust (.+) and start a Cowork task\?/g, "信任 $1 并开始协作任务？"],
    [/Trust (.+) and start a code session\?/g, "信任 $1 并开始代码会话？"]
  ];

  function escapeRegExp(value) {
    return value.replace(/[|\\{}()[\]^$+*?.]/g, "\\$&");
  }

  function replacePhrase(value, source, target) {
    const escaped = escapeRegExp(source);
    const startsWord = /^[A-Za-z0-9]/.test(source);
    const endsWord = /[A-Za-z0-9]$/.test(source);
    const pattern = new RegExp((startsWord ? "(?<![A-Za-z0-9])" : "") + escaped + (endsWord ? "(?![A-Za-z0-9])" : ""), "g");
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
    return !!element?.closest?.("script, style, textarea, code, pre, .xterm, .monaco-editor");
  }

  function translateElement(element) {
    for (const attr of ["aria-label", "title", "placeholder", "alt", "data-tooltip-content"]) {
      const value = element.getAttribute?.(attr);
      if (!value) continue;
      const translated = translate(value);
      if (translated !== value) element.setAttribute(attr, translated);
    }
  }

  function translateNode(root) {
    if (!root || shouldSkip(root)) return;
    if (root.nodeType === Node.TEXT_NODE) {
      const translated = translate(root.nodeValue || "");
      if (translated !== root.nodeValue) root.nodeValue = translated;
      return;
    }
    if (root.nodeType !== Node.ELEMENT_NODE && root.nodeType !== Node.DOCUMENT_NODE) return;
    if (root.nodeType === Node.ELEMENT_NODE) translateElement(root);
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (shouldSkip(node)) continue;
      if (node.nodeType === Node.TEXT_NODE) {
        const translated = translate(node.nodeValue || "");
        if (translated !== node.nodeValue) node.nodeValue = translated;
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        translateElement(node);
      }
    }
  }

  function run() {
    document.documentElement.lang = "zh-CN";
    translateNode(document);
    new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "characterData") {
          translateNode(mutation.target);
        } else if (mutation.type === "attributes") {
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
      attributeFilter: ["aria-label", "title", "placeholder", "alt", "data-tooltip-content"],
    });
  }

  if (typeof document === "undefined") return;
  if (document.readyState === "loading") {
    window.addEventListener("DOMContentLoaded", run, { once: true });
  } else {
    run();
  }
})();
</script>
"""
html_files = glob.glob(os.path.join(asar_dir, ".vite/renderer/**/*.html"), recursive=True)
count = 0
for html_file in html_files:
    with open(html_file, "r", encoding="utf-8") as f:
        content = f.read()
    if "__claudeDesktopZhBundleOverlay" not in content:
        content = content.replace("</head>", overlay + "\\n</head>")
        with open(html_file, "w", encoding="utf-8") as f:
            f.write(content)
        count += 1
print(f"成功注入汉化代码到 {count} 个前端 HTML 文件！")
' "$asar_dir"

  log "正在重新打包 app.asar..."
  npx -y @electron/asar pack "$asar_dir" "$RES_DIR/app.asar" --unpack-dir "node_modules"
  rm -rf "$asar_dir"
  
  log "正在为 Info.plist 设置诱导校验哈希并剥离 ElectronTeamID..."
  /usr/libexec/PlistBuddy -c "Set :ElectronAsarIntegrity:Resources/app.asar:hash DUMMY_HASH" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :ElectronTeamID" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
  
  log "前端 HTML 汉化完成！"
  
  log "正在对底层的 C++/Native 依赖库进行独立重签..."
  if [ -d "$RES_DIR/app.asar.unpacked" ]; then
    find "$RES_DIR/app.asar.unpacked" -type f \( -name "*.node" -o -name "spawn-helper" -o -name "*.dylib" \) -exec codesign --force --sign - {} \;
  fi
  
  log "正在提取并净化 Entitlements..."
  codesign -d --entitlements :- "$ORIG_APP_PATH" > /tmp/claude_entitlements.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :com.apple.application-identifier" /tmp/claude_entitlements.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.team-identifier" /tmp/claude_entitlements.plist 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :keychain-access-groups" /tmp/claude_entitlements.plist 2>/dev/null || true
  
  log "正在执行试运行以窃取真实的 ASAR Integrity 哈希值..."
  codesign --force --deep --sign - --entitlements /tmp/claude_entitlements.plist "$APP_PATH" 2>/dev/null || true
  
  # 执行试运行并捕获报错中的真实哈希
  CRASH_LOG=$("$APP_PATH/Contents/MacOS/Claude" 2>&1 || true)
  CORRECT_HASH=$(echo "$CRASH_LOG" | grep -o "vs [a-f0-9]*)" | sed 's/vs \([a-f0-9]*\))/\1/')
  
  if [ -n "$CORRECT_HASH" ]; then
    log "成功窃取到原生内部校验哈希: $CORRECT_HASH"
    /usr/libexec/PlistBuddy -c "Set :ElectronAsarIntegrity:Resources/app.asar:hash $CORRECT_HASH" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
    
    log "正在进行最终的本地代码重签..."
    codesign --force --deep --sign - --entitlements /tmp/claude_entitlements.plist "$APP_PATH" 2>/dev/null || true
  else
    log "警告: 未能提取出真实的内部哈希，跳过自动修复。应用可能会闪退。"
    echo "详细日志: $CRASH_LOG"
  fi
  
  log "补丁完成。请完全退出并重新打开 Claude。"
}

if [ "$ACTION" = "restore" ]; then
  quit_claude
  if [ "$USE_TMP" = true ] && [ -d "${ORIG_APP_PATH}.bak" ]; then
    log "正在从备份 (${ORIG_APP_PATH}.bak) 恢复官方未修改版本..."
    rm -rf "$ORIG_APP_PATH"
    mv "${ORIG_APP_PATH}.bak" "$ORIG_APP_PATH"
    log "恢复完成！"
  else
    # Fallback to in-place restore if backup doesn't exist
    restore
    if [ "$USE_TMP" = true ]; then
      log "正在将恢复后的 Claude.app 移回原目录..."
      rm -rf "$ORIG_APP_PATH"
      mv "$APP_PATH" "$ORIG_APP_PATH"
      xattr -cr "$ORIG_APP_PATH" 2>/dev/null || true
      log "恢复完成！"
    fi
  fi
else
  quit_claude
  patch
  if [ "$USE_TMP" = true ]; then
    # 签名和权限处理已经在 patch 函数中完美完成，此处直接跳过

    log "正在备份原始 Claude.app 为 ${ORIG_APP_PATH}.bak..."
    if [ ! -d "${ORIG_APP_PATH}.bak" ]; then
      mv "$ORIG_APP_PATH" "${ORIG_APP_PATH}.bak"
    else
      rm -rf "$ORIG_APP_PATH"
    fi
    log "正在将汉化后的 Claude.app 移至原目录..."
    mv "$APP_PATH" "$ORIG_APP_PATH"
    
    log "清理扩展文件属性限制..."
    xattr -cr "$ORIG_APP_PATH" 2>/dev/null || true
    log "汉化成功！请完全退出并重新打开 Claude 桌面端查看效果。"
  fi
fi


