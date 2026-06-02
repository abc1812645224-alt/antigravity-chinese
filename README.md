# Claude macOS 汉化脚本

这个目录里现在有两套脚本：

- `one-click-desktop-zh.command`：汉化截图里的 Claude 桌面端/Cowork 界面。
- `one-click-install.command`：汉化终端里的 Claude Code 命令行输出。

如果你要汉化截图里的 `New task`、`Projects`、`How can I help you today?` 这些内容，请使用桌面端脚本。

## 桌面端一键汉化（全原生）

在 Finder 里双击：

```text
one-click-desktop-zh.command
```

或者在终端运行：

```bash
./patch-desktop.sh
```

**汉化特点与原理：**

- **零后台、性能无损：** 直接修改 Claude Desktop 内置的原生 i18n 语言包（`en-US.json`），不需要在后台运行守护进程或 CDP 调试服务，性能与官方原生完全一致。
- **自动突破 macOS 目录锁定保护：** 针对 macOS 对 `/Applications` 文件夹的只读和 App Translocation 限制，脚本会自动克隆 App 至 `/tmp` 去除限制，安全注入翻译后自动移回，并清理 Gatekeeper 属性。
- **安全备份机制：** 首次运行会自动将原始 App 备份为 `/Applications/Claude.app.bak`，完全保留原版洁净状态。

完成后重新打开 Claude 即可享受中文界面！

**卸载与恢复官方英文：**

```bash
./patch-desktop.sh --restore
```
*该命令会瞬间用备份的官方原版 `.bak` 覆盖当前版本，实现 100% 完美无损恢复。*


## 终端 Claude Code 汉化

下面这套只负责终端里的 `claude`/`claude-zh`，不影响桌面 App。

```bash
chmod +x ./install.sh
./install.sh
```

默认会：

- 自动探测真实 Claude Code 路径。
- 安装到 `~/.claude-zh`。
- 提供 `claude-zh` 命令。
- 在 `~/.claude-zh/bin` 里放一个 `claude` 影子命令。
- 给 `~/.zshrc` 和 `~/.bash_profile` 添加 PATH 配置块。

重新打开终端后运行：

```bash
claude-zh
```

如果保留默认 shadow 模式，也可以直接运行：

```bash
claude
```

## 常用选项

```bash
./install.sh --no-shadow
```

只安装 `claude-zh`，不让 `claude` 指向汉化包装层。

```bash
./install.sh --no-shellrc
```

不修改 shell 配置文件，适合手动管理 PATH。

```bash
./install.sh --real /opt/homebrew/bin/claude
```

手动指定真实 Claude Code 可执行文件。

```bash
./install.sh --status
```

查看真实 Claude 路径、当前 PATH 和 Python 3 状态。

```bash
./install.sh --uninstall
```

卸载并清理写入 `~/.zshrc`、`~/.bash_profile` 的 PATH 配置块。

## 自定义词典

词典文件在：

```text
~/.claude-zh/dictionary.tsv
```

格式是：

```text
英文短语<TAB>中文短语
```

只建议加入 Claude Code UI 固定短语，不建议加入过短的通用词，比如 `Run`、`File`、`Yes`。过短词容易误伤 Claude 输出的代码、日志或测试结果。

## 临时关闭汉化

```bash
CLAUDE_ZH_MODE=off claude-zh
```

如果默认 shadow 模式已启用：

```bash
CLAUDE_ZH_MODE=off claude
```

## 兼容性说明

- macOS Apple Silicon 和 Intel 都可用。
- 支持官方安装脚本、Homebrew cask、npm 全局安装等常见路径。
- Claude Code 现在可能是原生二进制，直接补丁会破坏签名、升级和安全边界，所以此方案默认不修改官方文件。
- 包装层需要 `python3` 才能在交互式 PTY 中做汉化。找不到 `python3` 时会自动退回原版 Claude Code，不影响使用。

## 设计边界

这个脚本做的是“终端 UI 短语汉化”，不是对 Claude 回复内容做机器翻译。这样做是为了避免把代码、命令输出、报错栈、测试日志翻译坏。

## 捐赠与支持

如果你觉得这个汉化项目对你有帮助，欢迎请作者喝杯咖啡！非常感谢你的支持！☕️

| 支付宝 (Alipay) | 微信支付 (WeChat Pay) |
| :---: | :---: |
| <img src="assets/alipay.jpg" width="280" /> | <img src="assets/wechat.jpg" width="280" /> |
