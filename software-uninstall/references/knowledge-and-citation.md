# 本地知识与引文规则

## 本地知识优先级

默认知识库路径：`~/Documents/knowledge/`

推荐检索命令：

```bash
rg -n "卸载|uninstall|remove|删除|清理" ~/Documents/knowledge -g '*.md'
rg -n "安装|install" ~/Documents/knowledge -g '*.md'
find ~/Documents/knowledge -type f | rg "<software>"
```

检索策略：
1. 先找 `<software> + 卸载关键词`
2. 没有卸载资料，再找 `<software> + 安装关键词`
3. 从安装文档中提取安装方式、版本、安装路径、依赖项
4. 用当前系统信息判断这些资料能否反推出可执行的卸载方法

## 适用性判断提示

### macOS

以下信号通常表示资料更可能适用：
- `brew install` / `brew install --cask`
- `mas install`
- `.app`
- `/Applications`
- `~/Library/Application Support`
- `~/Library/Preferences`
- `~/Library/LaunchAgents`
- `pkg` / `pkgutil`

### Linux

以下信号通常表示资料更可能适用：
- `apt` / `dpkg`
- `dnf` / `yum`
- `snap`
- `flatpak`
- `/etc`
- `systemctl`

### Windows

以下信号通常表示资料更可能适用：
- `winget`
- `scoop`
- `choco`
- `AppData`
- 注册表

## 网络来源选择顺序

只有本地资料不足或不适用时才查网络。

优先顺序：
1. 软件官方文档
2. 软件官方 GitHub 仓库 README / docs
3. 官方包管理器文档
4. 平台官方帮助文档
5. 可信技术文档，且要明确标注为次级来源

## 推荐官方链接

- Apple Support, Delete or uninstall apps on Mac:
  `https://support.apple.com/en-us/102610`
- Apple App Store User Guide, install and uninstall purchases on Mac:
  `https://support.apple.com/guide/app-store/install-and-uninstall-purchased-apps-fir0fb69db23/mac`
- Homebrew manpage:
  `https://docs.brew.sh/Manpage`
- Homebrew FAQ:
  `https://docs.brew.sh/FAQ`
- npm Docs, uninstalling packages and dependencies:
  `https://docs.npmjs.com/uninstalling-packages-and-dependencies/`
- npm CLI uninstall docs:
  `https://docs.npmjs.com/cli/v11/commands/npm-uninstall/`
- pipx docs:
  `https://pipx.pypa.io/stable/docs/`
- mas README:
  `https://github.com/mas-cli/mas`

## 引文规则

- 每个关键结论后给出链接
- 只摘录最短必要原句
- 能用概括就不用长引文
- 如果结论来自推断，必须明确写“根据当前系统信息推断”
- 如果来源不是官方，必须标注“次级来源”

## 结论标注模板

```markdown
- 官方建议优先使用应用自带卸载器，然后再考虑手动删除应用包。
  来源：Apple Support <https://support.apple.com/en-us/102610>

- 该工具当前由 Homebrew 管理，可优先使用 `brew uninstall <name>`。
  来源：Homebrew Manpage <https://docs.brew.sh/Manpage>

- 根据本机为 macOS 且已检测到 `brew`，本地安装记录中的 Homebrew 方法可用。
  说明：这是基于本地记录与当前系统信息的推断。
```
