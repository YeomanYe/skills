# 本地知识与引文规则

适用于 `director-ops` 的 `install` 与 `uninstall` 两个 mode。

## 本地知识库优先级

默认知识库路径：`~/Documents/knowledge/`

### install mode 检索

```bash
rg -n "安装|install|setup" ~/Documents/knowledge -g '*.md'
find ~/Documents/knowledge -type f | rg "<software>"
```

检索顺序：
1. 找 `<software>-install.md` 或 `<software>-*.md`
2. 提取推荐安装方式、系统要求、依赖项、已知坑、PATH 配置

### uninstall mode 检索

```bash
rg -n "卸载|uninstall|remove|删除|清理" ~/Documents/knowledge -g '*.md'
rg -n "安装|install" ~/Documents/knowledge -g '*.md'
find ~/Documents/knowledge -type f | rg "<software>"
```

检索顺序：
1. 先找 `<software> + 卸载关键词`（`<software>-uninstall.md`）
2. 没有卸载资料，再找 `<software> + 安装关键词`（`<software>-install.md`）
3. 从安装文档提取安装方式、版本、安装路径、依赖项
4. 用当前系统信息判断这些资料能否反推出**可执行**的卸载方法

优先级：本地卸载文档 > 本地安装文档反推 > 网络资料。本地同时有装卸文档时，卸载文档优先。

## 适用性判断提示（uninstall mode 重点）

只要资料与当前系统不匹配，就不能直接采用。判断维度：平台、安装方式、版本范围、路径。

### macOS

以下信号通常表示资料更可能适用：
- `brew install` / `brew install --cask`
- `mas install`
- `.app` / `/Applications`
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

安装方式与卸载方式的对应关系：
- `brew install` ↔ `brew uninstall`
- `brew install --cask` ↔ `brew uninstall --cask`
- `npm install -g` ↔ `npm uninstall -g`
- `pipx install` ↔ `pipx uninstall`
- App Store 安装 ↔ 官方卸载方式 / `mas uninstall`

如果本地安装文档只能证明"可能如何安装"，不能据此直接删用户数据；此时最多输出候选路径和验证方法。

## 网络来源选择顺序

只有本地资料不足或不适用时才查网络。

优先顺序：
1. 软件官方文档
2. 软件官方 GitHub 仓库 README / docs
3. 官方包管理器文档
4. 平台官方帮助文档
5. 可信技术文档，且明确标注为次级来源

## 推荐官方链接

### 安装相关

- Homebrew Manpage：`https://docs.brew.sh/Manpage`
- Homebrew Installation：`https://docs.brew.sh/Installation`
- npm CLI install docs：`https://docs.npmjs.com/cli/v11/commands/npm-install/`
- pipx docs：`https://pipx.pypa.io/stable/docs/`
- Cargo install：`https://doc.rust-lang.org/cargo/commands/cargo-install.html`

### 卸载相关

- Apple Support, Delete or uninstall apps on Mac：`https://support.apple.com/en-us/102610`
- Apple App Store User Guide, install and uninstall purchases on Mac：
  `https://support.apple.com/guide/app-store/install-and-uninstall-purchased-apps-fir0fb69db23/mac`
- Homebrew FAQ：`https://docs.brew.sh/FAQ`
- npm Docs, uninstalling packages：`https://docs.npmjs.com/uninstalling-packages-and-dependencies/`
- npm CLI uninstall docs：`https://docs.npmjs.com/cli/v11/commands/npm-uninstall/`
- mas README：`https://github.com/mas-cli/mas`

## 引文规则

- 每个关键结论后给出链接
- 只摘录最短必要原句，能用概括就不用长引文
- 如果结论来自推断，必须明确写"根据当前系统信息推断"
- 如果来源不是官方，必须标注"次级来源"

## 结论标注模板

```markdown
- 官方建议优先使用应用自带卸载器，然后再考虑手动删除应用包。
  来源：Apple Support <https://support.apple.com/en-us/102610>

- 该工具当前由 Homebrew 管理，可优先使用 `brew uninstall <name>`。
  来源：Homebrew Manpage <https://docs.brew.sh/Manpage>

- 根据本机为 macOS 且已检测到 `brew`，本地安装记录中的 Homebrew 方法可用。
  说明：这是基于本地记录与当前系统信息的推断。
```
