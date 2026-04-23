---
name: software-uninstall
description: Use when uninstalling software, apps, CLI tools, or packages and you need system-aware removal steps, local-knowledge-first guidance, configuration backup, post-uninstall verification, and a recorded uninstall log
---

# Software Uninstall Guide

## 概述

用于卸载软件、应用和命令行工具的标准流程。

核心原则：
- 先查本地知识库，优先卸载资料，其次安装资料反推
- 先判断资料是否适用于当前系统，再决定是否可执行
- 本地资料不足时才查网络，优先官方资料，并附引文与链接
- 先备份配置和重要数据，再执行卸载
- 只有在验证卸载无误后，才允许删除残留数据和备份外的数据
- 记录版本、操作时间、卸载方法、删除路径和注意事项

## 适用范围

- 优先支持 `macOS`
- `Linux`、`Windows` 仅在本地知识或网络资料足够明确时提供步骤
- 如果系统不匹配、来源不可信或关键步骤无法验证，必须明确降级，而不是猜测

## 需要先读取的文件

- 本地知识与引文规则：`references/knowledge-and-citation.md`
- 卸载记录模板：`references/record-template.md`
- 测试用例：`tests/cases.md`

## 核心流程

### 1. 环境识别

先收集当前环境信息：

```bash
uname -s
uname -m
sw_vers 2>/dev/null
cat /etc/os-release 2>/dev/null
command -v brew
command -v mas
command -v npm
command -v pipx
```

至少明确：
- 操作系统与版本
- CPU 架构
- 相关包管理器是否存在
- 目标软件当前是否已安装
- 目标软件当前版本

如果无法确认目标软件是否存在，不要直接生成删除步骤；先给出定位方法。

### 2. 资料检索

先在 `~/Documents/knowledge/` 检索本地资料。

检索顺序：
1. 目标软件 + `卸载|uninstall|remove|删除|清理`
2. 目标软件 + `安装|install`
3. 目标软件 + 包管理器名

优先级：
1. 本地卸载文档
2. 本地安装文档反推的卸载方式
3. 网络资料

如果本地有卸载文档和安装文档，卸载文档优先。

### 3. 判断资料是否适用

只要资料与当前系统不匹配，就不能直接采用。

适用性判断包括：
- 平台是否匹配：例如 `brew`、`Launchpad`、`Finder`、`~/Library` 仅适用于 macOS
- 安装方式是否匹配：`brew install` 对应 `brew uninstall`；`npm install -g` 对应 `npm uninstall -g`
- 版本范围是否匹配：文档写明旧版本、Beta 版或特殊发行版时，需要说明差异
- 路径是否匹配：例如 `.app`、`~/Library/Application Support/`、`~/.config/`

如果本地安装文档只能证明“可能如何安装”，不能据此直接删除用户数据；此时最多输出候选路径和验证方法。

### 4. 必要时查网络

仅当本地资料不足或不适用时，才查网络。

要求：
- 优先官方文档、官方仓库 README、官方 CLI 手册
- 必须附链接
- 必须标注关键结论来自哪个来源
- 只摘录最短必要引文，避免长段复制

macOS 常见优先来源：
- Apple Support：应用卸载、App Store 应用删除
- Homebrew Docs：`brew uninstall`、cask 卸载
- npm Docs：`npm uninstall` / `npm uninstall -g`
- pipx Docs：`pipx uninstall`
- 目标软件官方文档或官方仓库 README

### 5. 形成卸载计划

在执行前，必须输出可审查的卸载计划。

计划至少包含：
- 当前系统信息
- 目标软件名称
- 已安装版本与发现方式
- 采用的卸载方法
- 每一步操作说明
- 每一步的风险
- 需要备份的配置/数据路径
- 需要保留的数据
- 验证方式
- 可选删除的数据路径
- 资料来源与链接

步骤要按以下顺序组织：
1. 停止正在运行的相关进程或服务
2. 导出版本与当前状态
3. 备份配置和重要数据
4. 执行软件卸载
5. 验证软件已卸载且系统正常
6. 删除残留数据
7. 记录结果

### 6. 执行前确认

任何真正会卸载软件、删除配置、删除目录或清空缓存的操作，都必须先向用户明确说明影响并等待确认。

确认内容至少包括：
- 即将删除的软件
- 影响范围
- 是否会删除配置或用户数据
- 是否已完成备份

在用户确认前，不要执行破坏性命令。

### 7. 备份配置和重要数据

卸载前必须先识别并备份：
- 配置文件
- 本地数据库
- 用户生成内容
- License、Token、导出文件或工作区

如果无法确认哪些目录属于用户数据，宁可多备份、少删除。

备份要求：
- 记录备份时间
- 记录备份路径
- 记录备份内容摘要
- 备份完成后再继续卸载

### 8. 执行卸载

按检测到的安装方式选择最小破坏路径：

- `Homebrew formula/cask`：优先 `brew uninstall`
- `npm 全局包`：优先 `npm uninstall -g`
- `pipx 包`：优先 `pipx uninstall`
- `Mac App Store 应用`：优先官方卸载方式，必要时用 `mas uninstall`
- 自带卸载器的 `.app`：优先运行官方卸载器
- 单独的 `.app`：按 Apple 支持文档从 Finder / Launchpad 删除
- `pkg` 安装的软件：先确认 receipt 和官方卸载方法，再处理 `pkgutil` 相关信息

不要混用安装方式。例如：
- 不要用手动删目录替代明确可用的官方卸载器
- 不要先删 `~/Library` 再尝试运行卸载命令
- 不要只删除二进制而保留后台服务、LaunchAgent、登录项

### 9. 验证卸载结果

删除数据前必须验证：
- 主命令、应用或服务已不存在，或无法再被启动
- 相关包管理器中已不再列出该软件
- 关键系统功能未受影响
- 备份文件可见且路径正确

常见验证方式：
- `command -v <tool>`
- `<tool> --version`
- `brew list --formula | rg '^<name>$'`
- `brew list --cask | rg '^<name>$'`
- `mas list`
- 检查 `/Applications/`、`~/Applications/`
- 检查 LaunchAgent、Login Items、后台服务是否已移除

如果卸载结果异常，不要继续删数据；先报告问题并保留备份。

### 10. 删除残留数据

只有在第 9 步确认没有问题后，才允许删除残留数据。

删除前要再次区分：
- 可以删除：缓存、日志、临时状态、明确属于该软件的 support files
- 默认保留：用户项目、导出文件、工作目录、未知用途目录

如果某个目录可能同时包含用户数据和程序状态，默认不删，除非用户再次确认。

### 11. 记录知识库

完成后在本地知识库记录一次卸载记录。

默认位置：
- `~/Documents/knowledge/<software>-uninstall.md`

如果已有同名文档，更新而不是重复创建。

记录必须包含：
- 软件名称
- 卸载时间
- 操作系统与版本
- 软件版本
- 安装来源或安装方式
- 卸载方式
- 备份路径
- 删除的数据路径
- 验证结果
- 使用的资料来源和链接
- 注意事项

记录格式参考 `references/record-template.md`。

## 输出要求

输出应明确区分：
- `当前环境`
- `资料来源`
- `适用性判断`
- `卸载步骤`
- `备份计划`
- `验证方式`
- `拟删除的数据`
- `注意事项`
- `知识库记录位置`

如果使用网络资料，必须在相关步骤后附来源链接。

## 护栏

- 没有系统匹配证据时，不要编造步骤
- 没有备份前，不要删除配置和数据
- 没有验证通过前，不要清理残留数据
- 没有用户确认前，不要执行破坏性命令
- 不能把“安装文档推测”写成“已验证可执行的卸载方案”
- 对 `pkg`、内核扩展、系统扩展、登录项、LaunchAgent、网络代理类软件，要额外提醒影响范围

## 完成判定

只有同时满足以下条件，才能宣称完成：
- 已给出适用于当前系统的卸载方案
- 已完成或明确给出备份
- 已完成或明确给出卸载后的验证
- 仅在验证无误后才删除数据
- 已记录版本、操作时间和注意事项
