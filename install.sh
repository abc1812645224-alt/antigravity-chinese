#!/usr/bin/env bash
set -euo pipefail

APP_NAME="claude-zh"
INSTALL_DIR="${CLAUDE_ZH_HOME:-$HOME/.claude-zh}"
BIN_DIR="$INSTALL_DIR/bin"
LIB_DIR="$INSTALL_DIR/lib"
CONF_FILE="$INSTALL_DIR/config.env"
DICT_FILE="$INSTALL_DIR/dictionary.tsv"
WRAPPER="$BIN_DIR/claude-zh"
SHADOW="$BIN_DIR/claude"
MARKER_BEGIN="# >>> claude-zh >>>"
MARKER_END="# <<< claude-zh <<<"

ACTION="install"
WRITE_SHELLRC=1
INSTALL_SHADOW=1
REAL_CLAUDE="${CLAUDE_ZH_REAL:-}"

usage() {
  cat <<'EOF'
Claude Code macOS 汉化包装脚本

用法:
  ./install.sh                 安装 claude-zh，并默认让 claude 指向汉化包装层
  ./install.sh --no-shadow     只安装 claude-zh，不覆盖 claude 命令
  ./install.sh --no-shellrc    不修改 ~/.zshrc 或 ~/.bash_profile
  ./install.sh --real PATH     指定真实 Claude Code 可执行文件
  ./install.sh --status        查看安装状态
  ./install.sh --uninstall     卸载并清理 shell 配置块

运行:
  claude-zh                    使用汉化包装层
  claude                       若安装时启用了 shadow，则同样进入汉化包装层

临时关闭汉化:
  CLAUDE_ZH_MODE=off claude-zh
EOF
}

log() {
  printf '[%s] %s\n' "$APP_NAME" "$*"
}

die() {
  printf '[%s] 错误: %s\n' "$APP_NAME" "$*" >&2
  exit 1
}

quote_sh() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

is_under_install_dir() {
  case "$1" in
    "$INSTALL_DIR"/*) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_path() {
  local target="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$target" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
  else
    perl -MCwd=realpath -e 'print realpath($ARGV[0]) || $ARGV[0]' "$target"
    printf '\n'
  fi
}

discover_real_claude() {
  if [ -n "$REAL_CLAUDE" ]; then
    [ -x "$REAL_CLAUDE" ] || die "--real 指向的文件不可执行: $REAL_CLAUDE"
    resolve_path "$REAL_CLAUDE"
    return
  fi

  local found=""
  if found="$(command -v claude 2>/dev/null || true)" && [ -n "$found" ]; then
    found="$(resolve_path "$found")"
    if ! is_under_install_dir "$found"; then
      printf '%s\n' "$found"
      return
    fi
  fi

  local candidates=(
    "/opt/homebrew/bin/claude"
    "/usr/local/bin/claude"
    "$HOME/.local/bin/claude"
    "$HOME/.npm-global/bin/claude"
  )

  local npm_prefix=""
  if command -v npm >/dev/null 2>&1; then
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [ -n "$npm_prefix" ]; then
      candidates+=("$npm_prefix/bin/claude")
    fi
  fi

  local brew_prefix=""
  if command -v brew >/dev/null 2>&1; then
    brew_prefix="$(brew --prefix 2>/dev/null || true)"
    if [ -n "$brew_prefix" ]; then
      candidates+=("$brew_prefix/bin/claude")
    fi
  fi

  local c
  for c in "${candidates[@]}"; do
    if [ -x "$c" ]; then
      c="$(resolve_path "$c")"
      if ! is_under_install_dir "$c"; then
        printf '%s\n' "$c"
        return
      fi
    fi
  done

  printf ''
}

write_dictionary() {
  if [ -f "$DICT_FILE" ]; then
    return
  fi

  cat >"$DICT_FILE" <<'EOF'
# Claude Code UI 汉化词典。格式: 英文<TAB>中文
# 这里只放保守短语，避免误伤 Claude 输出的代码、日志、测试结果。
Welcome to Claude Code	欢迎使用 Claude Code
Claude Code	Claude Code
Do you want to proceed?	是否继续？
Are you sure you want to continue?	确定要继续吗？
Press Enter to continue	按 Enter 继续
Press Enter	按 Enter
Enter to continue	回车继续
Press Esc to interrupt	按 Esc 中断
Ctrl+C to exit	Ctrl+C 退出
Ctrl+C again to quit	再次按 Ctrl+C 退出
Permission required	需要权限
Permission denied	权限被拒绝
Allow this command?	允许执行此命令？
Allow this tool?	允许使用此工具？
Allow	允许
Deny	拒绝
Accept	接受
Reject	拒绝
Continue	继续
Cancel	取消
Update available	有可用更新
Checking for updates	正在检查更新
Installing update	正在安装更新
Restart required	需要重启
Authentication required	需要登录认证
Login required	需要登录
Log in	登录
Log out	退出登录
Signed in	已登录
Not signed in	未登录
Loading	加载中
Thinking	思考中
Working	处理中
Done	完成
Error	错误
Warning	警告
Failed	失败
Success	成功
Retry	重试
Try again	重试
Network error	网络错误
Rate limit exceeded	已达到频率限制
Session expired	会话已过期
New session	新会话
Resume session	恢复会话
Choose a conversation	选择一个会话
Choose an option	选择一个选项
Search files	搜索文件
Reading file	正在读取文件
Writing file	正在写入文件
Editing file	正在编辑文件
Creating file	正在创建文件
Deleting file	正在删除文件
Running command	正在运行命令
Command output	命令输出
No changes	没有变更
Changes saved	变更已保存
EOF
}

write_runtime() {
  cat >"$LIB_DIR/claude_zh_runtime.py" <<'PY'
#!/usr/bin/env python3
import codecs
import os
import pty
import re
import select
import signal
import subprocess
import sys
import termios
import tty

ANSI_RE = re.compile(
    r"(\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07]*(?:\x07|\x1b\\)|\x1b[@-_])"
)


def load_dictionary(path):
    pairs = []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            for raw in fh:
                line = raw.rstrip("\n")
                if not line or line.lstrip().startswith("#") or "\t" not in line:
                    continue
                src, dst = line.split("\t", 1)
                if src and dst:
                    pairs.append((src, dst))
    except FileNotFoundError:
        pass
    pairs.sort(key=lambda item: len(item[0]), reverse=True)
    return pairs


def translate_text(text, pairs):
    for src, dst in pairs:
        text = text.replace(src, dst)
    return text


def translate_ansi_safe(text, pairs):
    if not pairs:
        return text
    out = []
    pos = 0
    for match in ANSI_RE.finditer(text):
        if match.start() > pos:
            out.append(translate_text(text[pos : match.start()], pairs))
        out.append(match.group(0))
        pos = match.end()
    if pos < len(text):
        out.append(translate_text(text[pos:], pairs))
    return "".join(out)


def main():
    real = os.environ.get("CLAUDE_ZH_REAL")
    dictionary = os.environ.get("CLAUDE_ZH_DICT")
    if not real:
        print("claude-zh: CLAUDE_ZH_REAL 未配置", file=sys.stderr)
        return 127

    if os.environ.get("CLAUDE_ZH_MODE", "on").lower() in {"0", "off", "false", "no"}:
        os.execv(real, [real] + sys.argv[1:])

    pairs = load_dictionary(dictionary) if dictionary else []

    if not os.isatty(sys.stdin.fileno()) or not os.isatty(sys.stdout.fileno()):
        proc = subprocess.Popen(
            [real] + sys.argv[1:],
            stdin=sys.stdin.buffer,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        decoder = codecs.getincrementaldecoder("utf-8")("replace")
        assert proc.stdout is not None
        while True:
            data = proc.stdout.read(4096)
            if not data:
                break
            text = decoder.decode(data)
            translated = translate_ansi_safe(text, pairs)
            os.write(sys.stdout.fileno(), translated.encode("utf-8", "replace"))
        tail = decoder.decode(b"", final=True)
        if tail:
            translated = translate_ansi_safe(tail, pairs)
            os.write(sys.stdout.fileno(), translated.encode("utf-8", "replace"))
        return proc.wait()

    pid, master_fd = pty.fork()
    if pid == 0:
        os.environ.setdefault("LANG", "zh_CN.UTF-8")
        os.environ.setdefault("LC_CTYPE", "zh_CN.UTF-8")
        os.execv(real, [real] + sys.argv[1:])

    old_tty = None
    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    stdin_is_tty = os.isatty(stdin_fd)
    if stdin_is_tty:
        old_tty = termios.tcgetattr(stdin_fd)
        tty.setraw(stdin_fd)

    decoder = codecs.getincrementaldecoder("utf-8")("replace")

    def restore_tty():
        if old_tty is not None:
            try:
                termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old_tty)
            except termios.error:
                pass

    try:
        while True:
            read_fds = [master_fd]
            if stdin_is_tty:
                read_fds.append(stdin_fd)
            readable, _, _ = select.select(read_fds, [], [])

            if master_fd in readable:
                try:
                    data = os.read(master_fd, 4096)
                except OSError:
                    break
                if not data:
                    break
                text = decoder.decode(data)
                translated = translate_ansi_safe(text, pairs)
                os.write(stdout_fd, translated.encode("utf-8", "replace"))

            if stdin_is_tty and stdin_fd in readable:
                data = os.read(stdin_fd, 4096)
                if not data:
                    try:
                        os.close(master_fd)
                    except OSError:
                        pass
                    break
                os.write(master_fd, data)
    except KeyboardInterrupt:
        try:
            os.kill(pid, signal.SIGINT)
        except OSError:
            pass
    finally:
        restore_tty()

    _, status = os.waitpid(pid, 0)
    if os.WIFEXITED(status):
        return os.WEXITSTATUS(status)
    if os.WIFSIGNALED(status):
        return 128 + os.WTERMSIG(status)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
PY
  chmod +x "$LIB_DIR/claude_zh_runtime.py"
}

write_wrapper() {
  cat >"$WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR=$(quote_sh "$INSTALL_DIR")
CONF_FILE="\$INSTALL_DIR/config.env"

if [ -f "\$CONF_FILE" ]; then
  # shellcheck source=/dev/null
  . "\$CONF_FILE"
fi

if [ -z "\${CLAUDE_ZH_REAL:-}" ] || [ ! -x "\$CLAUDE_ZH_REAL" ]; then
  printf 'claude-zh: 找不到真实 Claude Code。请运行: %s --real /path/to/claude\\n' "$(quote_sh "$(pwd)/install.sh")" >&2
  exit 127
fi

export CLAUDE_ZH_REAL
export CLAUDE_ZH_DICT="\${CLAUDE_ZH_DICT:-\$INSTALL_DIR/dictionary.tsv}"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "\$INSTALL_DIR/lib/claude_zh_runtime.py" "\$@"
fi

printf 'claude-zh: 当前系统找不到 python3，已直接启动原版 Claude Code。安装 Xcode Command Line Tools 或 Python 3 后可启用终端汉化。\\n' >&2
exec "\$CLAUDE_ZH_REAL" "\$@"
EOF
  chmod +x "$WRAPPER"

  if [ "$INSTALL_SHADOW" -eq 1 ]; then
    ln -sf "claude-zh" "$SHADOW"
  else
    rm -f "$SHADOW"
  fi
}

write_config() {
  local real="$1"
  {
    printf 'CLAUDE_ZH_REAL=%s\n' "$(quote_sh "$real")"
  } >"$CONF_FILE"
}

patch_shellrc_file() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -Fq "$MARKER_BEGIN" "$file"; then
    return
  fi
  {
    printf '\n%s\n' "$MARKER_BEGIN"
    printf 'export PATH="%s:$PATH"\n' "$BIN_DIR"
    printf '%s\n' "$MARKER_END"
  } >>"$file"
}

patch_shellrcs() {
  [ "$WRITE_SHELLRC" -eq 1 ] || return
  patch_shellrc_file "$HOME/.zshrc"
  patch_shellrc_file "$HOME/.bash_profile"
}

remove_shellrc_block() {
  local file="$1"
  [ -f "$file" ] || return
  local tmp
  tmp="$(mktemp)"
  awk -v begin="$MARKER_BEGIN" -v end="$MARKER_END" '
    $0 == begin {skip=1; next}
    $0 == end {skip=0; next}
    skip != 1 {print}
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

status() {
  printf '安装目录: %s\n' "$INSTALL_DIR"
  printf '包装命令: %s\n' "$WRAPPER"
  if [ -f "$CONF_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONF_FILE"
    printf '真实 Claude: %s\n' "${CLAUDE_ZH_REAL:-未配置}"
  else
    printf '真实 Claude: 未配置\n'
  fi
  if command -v claude >/dev/null 2>&1; then
    printf '当前 PATH 中的 claude: %s\n' "$(command -v claude)"
  else
    printf '当前 PATH 中的 claude: 未找到\n'
  fi
  if command -v claude-zh >/dev/null 2>&1; then
    printf '当前 PATH 中的 claude-zh: %s\n' "$(command -v claude-zh)"
  else
    printf '当前 PATH 中的 claude-zh: 未找到，可能需要重新打开终端\n'
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf 'python3: %s\n' "$(command -v python3)"
  else
    printf 'python3: 未找到，包装层会退回原版 Claude Code\n'
  fi
}

install() {
  mkdir -p "$BIN_DIR" "$LIB_DIR"
  local real
  real="$(discover_real_claude)"
  if [ -z "$real" ]; then
    log "未在 PATH 中发现 claude。仍会安装包装层，之后可用 ./install.sh --real /path/to/claude 重新配置。"
    real="/usr/local/bin/claude"
  fi

  write_dictionary
  write_runtime
  write_config "$real"
  write_wrapper
  patch_shellrcs

  log "安装完成。"
  log "真实 Claude: $real"
  log "打开新终端后可运行: claude-zh"
  if [ "$INSTALL_SHADOW" -eq 1 ]; then
    log "已安装 claude 影子命令；新终端中 claude 会进入汉化包装层。"
  fi
}

uninstall() {
  remove_shellrc_block "$HOME/.zshrc"
  remove_shellrc_block "$HOME/.bash_profile"
  rm -rf "$INSTALL_DIR"
  log "已卸载。重新打开终端后 PATH 配置生效。"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install) ACTION="install" ;;
    --status) ACTION="status" ;;
    --uninstall) ACTION="uninstall" ;;
    --no-shellrc) WRITE_SHELLRC=0 ;;
    --shadow) INSTALL_SHADOW=1 ;;
    --no-shadow) INSTALL_SHADOW=0 ;;
    --real)
      shift
      [ "$#" -gt 0 ] || die "--real 需要一个路径"
      REAL_CLAUDE="$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "未知参数: $1" ;;
  esac
  shift
done

case "$ACTION" in
  install) install ;;
  status) status ;;
  uninstall) uninstall ;;
  *) die "未知动作: $ACTION" ;;
esac
