# 知识库记录模板

`director-ops` 完成后必须在 `~/Documents/knowledge/` 记录一次操作。
已有同名文档时**更新**而不是重复创建。

---

## install 记录模板

写入 `~/Documents/knowledge/<tool>-install.md`：

```markdown
# <工具名> 安装记录

## 环境
- OS: <macOS 14.0 / Ubuntu 22.04 / ...>
- 架构: <arm64 / x86_64>
- 安装日期: <YYYY-MM-DD>
- 安装方式: <homebrew / pip / pipx / cargo / npm / binary release / 源码>

## 安装步骤
1. <step 1 命令>
2. <step 2 命令>
3. ...

## 验证命令
- `<tool> --version` → <expected output>
- `which <tool>` → <expected path>
- `<tool> <basic-command>` → <expected result>

## 注意事项
- <已知坑 / 配置项 / PATH 设置 / 依赖>

## 参考
- <官方文档 URL>
```

---

## uninstall 记录模板

写入 `~/Documents/knowledge/<tool>-uninstall.md`：

```markdown
# <软件名> 卸载记录

## 基本信息
- 卸载时间：<YYYY-MM-DD HH:mm:ss Z>
- 操作系统：<系统名>
- 系统版本：<版本>
- 软件版本：<版本；如未知写未知>
- 安装方式：<Homebrew / npm / pipx / App Store / pkg / 手动安装 / 未知>
- 卸载方式：<具体方法>

## 资料来源
- 本地知识：
  - <文件路径或"无">
- 网络资料：
  - <标题>：<链接>

## 卸载步骤
1. <步骤>
2. <步骤>
3. ...

## 备份信息
- 备份时间：<时间>
- 备份路径：<路径>
- 备份内容：
  - <内容 1>
  - <内容 2>

## 删除的数据
- 已删除：
  - <路径 1>
  - <路径 2>
- 保留：
  - <路径 1>
  - <原因>

## 验证结果
- 命令/检查 1：<结果>
- 命令/检查 2：<结果>
- 是否确认卸载无误：<是/否>

## 注意事项
- <注意事项 1>
- <注意事项 2>
```
