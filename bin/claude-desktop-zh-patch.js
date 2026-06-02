#!/usr/bin/env node
'use strict';

const { execFileSync, spawn } = require('child_process');

const DEBUG_PORT = Number(process.env.CLAUDE_ZH_DEBUG_PORT || 23977);
const APP_PATH = process.env.CLAUDE_ZH_APP_PATH || '/Applications/Claude.app';
let lastRelaunch = 0;

const overlaySource = String.raw`
(() => {
  if (window.__claudeDesktopZhPatchInstalled === 11) return;
  window.__claudeDesktopZhPatchInstalled = 11;

  const phrases = new Map([
    ['Claude', 'Claude'],
    ['Cowork', '协作'],
    ['Code', '代码'],
    ['New task', '新任务'],
    ['Projects', '项目'],
    ['Scheduled', '计划任务'],
    ['Live artifacts', '实时作品'],
    ['Customize', '自定义'],
    ['Recents', '最近'],
    ["Let's knock something off your list", '让我们完成清单上的事项'],
    ['Learn how to use Cowork safely.', '了解如何安全使用协作功能。'],
    ['Learn how to use Cowork safely', '了解如何安全使用协作功能'],
    ['How can I help you today?', '今天我能帮你做什么？'],
    ['Work in a project', '在项目中工作'],
    ['Active', '进行中'],
    ['Clear active', '清除进行中'],
    ['General chat', '普通聊天'],
    ['Untitled', '未命名'],
    ['Home', '首页'],
    ['Today', '今天'],
    ['Yesterday', '昨天'],
    ['Older', '更早'],
    ['View all', '查看全部'],
    ['Search', '搜索'],
    ['Settings', '设置'],
    ['Help', '帮助'],
    ['Gateway', '网关'],
    ['New chat', '新聊天'],
    ['Start a new chat', '开始新聊天'],
    ['Ask anything', '随便问点什么'],
    ['Message Claude', '给 Claude 发送消息'],
    ['Type a message', '输入消息'],
    ['Add files', '添加文件'],
    ['Upload file', '上传文件'],
    ['Choose files', '选择文件'],
    ['Open menu', '打开菜单'],
    ['Open sidebar', '打开侧边栏'],
    ['Close sidebar', '关闭侧边栏'],
    ['Sign in', '登录'],
    ['Sign out', '退出登录'],
    ['Log in', '登录'],
    ['Log out', '退出登录'],
    ['Account', '账户'],
    ['Profile', '个人资料'],
    ['Appearance', '外观'],
    ['General', '通用'],
    ['Notifications', '通知'],
    ['Privacy', '隐私'],
    ['Developer', '开发者'],
    ['Connectors', '连接器'],
    ['Artifacts', '作品'],
    ['Create', '创建'],
    ['Cancel', '取消'],
    ['Continue', '继续'],
    ['Save', '保存'],
    ['Delete', '删除'],
    ['Remove', '移除'],
    ['Edit', '编辑'],
    ['Rename', '重命名'],
    ['Copy', '复制'],
    ['Done', '完成'],
    ['Retry', '重试'],
    ['Try again', '重试'],
    ['Allow', '允许'],
    ['Deny', '拒绝'],
    ['Accept', '接受'],
    ['Reject', '拒绝'],
    ['Open', '打开'],
    ['Close', '关闭'],
    ['Back', '返回'],
    ['Next', '下一步'],
    ['Loading...', '加载中...'],
    ['Loading', '加载中'],
    ['Scanning...', '扫描中...'],
    ['Searching...', '搜索中...'],
    ['Error', '错误'],
    ['Warning', '警告'],
    ['Success', '成功'],
    ['Failed', '失败'],
    ['Try Claude Code', '试用 Claude Code'],
    ['Set up Cowork', '设置协作'],
    ['Power through tasks with Cowork', '用协作功能高效完成任务'],
    ['You’re all set up with Cowork', '协作功能已设置完成'],
    ["You're all set up with Cowork", '协作功能已设置完成'],
    ['Create task', '创建任务'],
    ['New task draft', '新任务草稿'],
    ['Start task', '开始任务'],
    ['Stop task', '停止任务'],
    ['Task complete', '任务完成'],
    ['Task failed', '任务失败'],
  ]);

  const patterns = [
    [/(\d+)\s+days?\s+ago/g, '$1 天前'],
    [/(\d+)\s+hours?\s+ago/g, '$1 小时前'],
    [/(\d+)\s+minutes?\s+ago/g, '$1 分钟前'],
    [/(\d+)\s+seconds?\s+ago/g, '$1 秒前'],
    [/just now/gi, '刚刚'],
    [/See all \((\d+)\)/g, '查看全部 ($1)'],
    [/New session in (.+)/g, '在 $1 中新建会话'],
    [/Trust (.+) and start a Cowork task\?/g, '信任 $1 并开始协作任务？'],
    [/Trust (.+) and start a code session\?/g, '信任 $1 并开始代码会话？'],
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
    for (const [source, target] of [...phrases].sort((a, b) => b[0].length - a[0].length)) {
      next = replacePhrase(next, source, target);
    }
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

  if (document.readyState === 'loading') {
    window.addEventListener('DOMContentLoaded', run, { once: true });
  } else {
    run();
  }
})();
`;

function mainPid() {
  try {
    const output = execFileSync('/usr/bin/pgrep', ['-f', '/Claude\\.app/Contents/MacOS/Claude$'], { encoding: 'utf8' });
    return output.trim().split(/\s+/)[0] || null;
  } catch {
    return null;
  }
}

function debugPorts() {
  const pid = mainPid();
  if (!pid) return [];
  try {
    const output = execFileSync('/usr/sbin/lsof', ['-nP', '-a', '-p', pid, '-iTCP', '-sTCP:LISTEN'], { encoding: 'utf8' });
    const ports = [...output.matchAll(/127\.0\.0\.1:(\d+)\s+\(LISTEN\)/g)].map((match) => Number(match[1]));
    return [...new Set(ports)];
  } catch {
    return [];
  }
}

function launchClaude() {
  // Launch Electron binary directly to ensure --remote-debugging-port is passed.
  // Using `open --args` often silently drops Chromium flags on macOS.
  const binary = `${APP_PATH}/Contents/MacOS/Claude`;
  spawn(binary, [
    `--remote-debugging-port=${DEBUG_PORT}`,
    '--remote-allow-origins=*',
  ], { detached: true, stdio: 'ignore', env: { ...process.env } }).unref();
}

function quitClaude() {
  return new Promise((resolve) => {
    spawn('/usr/bin/osascript', ['-e', 'tell application "Claude" to quit'], { stdio: 'ignore' })
      .on('error', () => resolve())
      .on('close', () => resolve());
    // Fallback resolve after 3s
    setTimeout(resolve, 3000);
  });
}

function waitForExit(timeout = 8000) {
  const start = Date.now();
  return new Promise((resolve) => {
    const check = () => {
      if (!mainPid() || Date.now() - start > timeout) { resolve(); return; }
      setTimeout(check, 500);
    };
    check();
  });
}

async function ensureDebuggableClaude() {
  const pid = mainPid();
  const ports = debugPorts();
  if (!pid) {
    launchClaude();
    return;
  }
  if (ports.length > 0) return;
  const now = Date.now();
  if (now - lastRelaunch < 60000) return;
  lastRelaunch = now;
  console.log('[claude-zh] Claude 未开启调试端口，正在重启...');
  await quitClaude();
  await waitForExit();
  launchClaude();
}

async function targetsForPort(port) {
  try {
    const response = await fetch(`http://127.0.0.1:${port}/json/list`, { signal: AbortSignal.timeout(1200) });
    if (!response.ok) return [];
    const targets = await response.json();
    return targets.filter((target) => target.type === 'page' && target.webSocketDebuggerUrl);
  } catch {
    return [];
  }
}

function cdpCall(ws, method, params = {}) {
  const id = cdpCall.nextId = (cdpCall.nextId || 0) + 1;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      ws.removeEventListener('message', onMessage);
      reject(new Error(`${method} timed out`));
    }, 1500);
    function onMessage(event) {
      const message = JSON.parse(event.data);
      if (message.id !== id) return;
      clearTimeout(timeout);
      ws.removeEventListener('message', onMessage);
      resolve(message);
    }
    ws.addEventListener('message', onMessage);
  });
}

async function injectTarget(target) {
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('websocket timed out')), 1500);
    ws.onopen = () => {
      clearTimeout(timeout);
      resolve();
    };
    ws.onerror = reject;
  });
  try {
    await cdpCall(ws, 'Page.addScriptToEvaluateOnNewDocument', { source: overlaySource });
    await cdpCall(ws, 'Runtime.evaluate', { expression: overlaySource, awaitPromise: false });
  } finally {
    ws.close();
  }
}

async function injectOnce() {
  let count = 0;
  const ports = debugPorts();
  const allPorts = ports.includes(DEBUG_PORT) ? ports : [DEBUG_PORT, ...ports];
  for (const port of [...new Set(allPorts)]) {
    for (const target of await targetsForPort(port)) {
      await injectTarget(target).then(() => count += 1).catch(() => {});
    }
  }
  return count;
}

async function watch() {
  for (;;) {
    ensureDebuggableClaude();
    await injectOnce().catch(() => {});
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }
}

if (process.argv.includes('--watch')) {
  watch();
} else {
  injectOnce().then((count) => {
    console.log(`Injected Claude Chinese overlay into ${count} page(s).`);
  });
}
