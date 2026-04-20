---
name: orchestrating-extension-publishing
description: Use when preparing to publish or update a browser extension to web stores (Chrome Web Store, Firefox AMO, Edge Add-ons), especially when the extension may have missing or outdated assets (icons, screenshots, promo tiles, descriptions, permissions justifications, version bumps) that need to be discovered, generated, confirmed, and submitted per each platform's rules. 用于浏览器扩展准备上架或更新到 Chrome Web Store / Firefox AMO / Edge Add-ons，尤其是可能存在缺失素材（图标、截图、宣传图、描述、权限理由、版本号）需要先排查、补齐、再按平台规则提交的场景。
---

# 扩展发布编排

## Overview

这个 skill 编排「浏览器扩展从 preflight 到提交」的完整链路。

它不替代 `ext-publishing-preflight`、`text-card` 或各平台上传工具。它的职责是：

- 先用 preflight 查出所有待完成项
- 对可以自动生成的图片素材转交 `text-card`
- 在所有缺口补齐前阻止发布
- 用户明确确认后，按项目约定方式整理提交 payload

默认不自动上传；只有用户明确要求「一把梭直接发」时才执行实际 API 调用。

## When to Use

- 准备把扩展上架到 Chrome Web Store / Firefox AMO / Edge Add-ons
- 准备发布一个新版本（version bump + 提交 review）
- 用户说「帮我发布这个扩展」「准备上架了」「submit to the store」「更新扩展版本」
- 有多个素材项不确定状态，需要一次性梳理

## When NOT to Use

- 只讨论扩展代码实现，不涉及发布
- 只做扩展内部功能调试
- 发布 VSCode extension / Obsidian plugin / 其他非浏览器扩展（本 skill 锁定浏览器扩展）
- 只是想跑一次 preflight 看看状态（直接用 `ext-publishing-preflight` 即可）

## Execution Default

默认一路推进到「已输出分平台提交 payload，并等待用户确认是否实际上传」。

在缺失项补齐 + 用户明确确认前，不得进入 Step 4。
在用户明确说「自动上传」「一把梭直接发」前，不要调用任何 store API / CLI 的上传命令。

## Required Workflow

按顺序执行：

1. 运行 `ext-publishing-preflight`
2. 分类缺失项 → 图片接力给 `text-card` / 非图片列入 user-must-provide
3. 输出缺口清单 + 注意事项 → 等待用户明确确认「全部就绪」
4. 按项目约定整理分平台提交 payload

Step 3 前不得进入 Step 4。不允许「看起来都 OK」就自己补全再提交。

## Step 1: 运行 preflight

调用 `ext-publishing-preflight`，拿到待完成项清单。

调用时把已知信息显式传入，避免下游重复追问：

- 用户已指定的目标平台（例如 `上架 Chrome` → 传 `[Chrome Web Store]`）
- 从 `package.json` / `README` 能读到的构建产物路径与构建命令
- 从 `manifest.json` 能读到的 name / version / permissions

至少应从 preflight 获取：

- 缺失的素材项（图标 / 截图 / 宣传图 / 描述 / 权限理由 / 隐私政策链接）
- 版本号与 manifest 的一致性
- 分平台独有要求的覆盖情况
- 阻塞项与建议项

若 preflight 未安装：fallback 到手工检查 `manifest.json` + `store-assets/` + 每个平台官方 checklist 最小集，并在最终报告中注明降级。

## Step 2: 分类缺失项

对 preflight 的缺失清单做三路分流：

### A. text-card 可生成

满足以下条件的图片交给 `text-card`：

- 文字为主的卡片：promo tile、hero banner、标题卡、slogan 图
- 尺寸 / 背景 / 排版可由 text-card 直接产出
- 不需要扩展真实运行截图

交接给 text-card 时必须提供：

- 目标尺寸（例：Chrome promo tile 440×280、marquee 1400×560）
- **目标场景 = 浏览器扩展商店素材**（绕过 text-card 默认的"公众号 / 小红书"平台反问）
- **模板选择提示**：若 text-card 的 `references/` 下没有匹配尺寸模板（当前版本就没有 440×280 / 1400×560），显式声明"本次属于 from-scratch 场景，不要硬套 rednote / wechat 模板"
- 文案（从 manifest `name` / `description` / 项目 README 抽取，不要瞎编）
- 样式约束（暗色 / 亮色 / 品牌色；若 `assets/` 有 icon，告知主色调）
- 输出文件名与落位目录

### B. 需要真实截图

扩展运行后的 UI 截图、popup 截图、options 页截图。`text-card` 无法生成。

这一类直接列入 **user-must-provide** 清单，给出：

- 需要几张
- 每张的尺寸要求
- 建议的取景（例：「显示 popup 的主功能页」）
- 落位目录

不要替用户用占位图蒙混过关。

### C. 非图片缺口

描述文本、权限理由、隐私政策链接、版本号等，整理成一份 checklist，列明：

- 字段名
- 目标平台
- 当前状态（缺 / 过时 / OK）
- 建议内容（能从 README / manifest / CHANGELOG 直接抽取的就抽，不能的只写「待用户填」）

## Step 3: 汇总并等待用户确认

输出一份结构化清单：

```md
## 扩展发布前检查

### 目标平台
- Chrome Web Store: ...
- Firefox AMO: ...
- Edge Add-ons: ...

### 已通过 text-card 生成
- <文件路径>: <用途>

### 需要你手动提供
- <项目>: <要求> → <落位>

### 非图片缺口
- <字段>: <平台> - <状态> - <建议>

### 注意事项
- <manifest version vs package.json 一致性>
- <permissions 是否触发 review 加严>
- <content_security_policy 变更>
- <隐私政策是否需要更新>
```

输出后明确询问：**「以上缺口全部处理好了吗？确认后我才会进入提交阶段。」**

以下含糊回应**不算**确认，收到时应再次澄清：

- 「嗯」「嗯嗯」「哦」
- 「ok 吧」「行吧」「好像可以」
- 「随便」「都行」「你看着办」

明确确认应类似「都处理好了」「可以提交」「go ahead」「开始发布」。

收到用户明确回复「某项还没好」或「先不发 X 平台」时，更新 payload 范围，再次等待确认；不要跳过。

## Step 4: 按项目约定整理 payload

### 探测项目的发布方式

按优先级读：

1. `package.json` 的 `scripts`（常见：`release:chrome`、`release:firefox`、`build:ext`、`web-ext build`）
2. `.github/workflows/release.yml` / `publish.yml`（看里面用什么上传工具）
3. `web-ext.config.js` / `web-ext-config.json`
4. `chrome-webstore-upload-cli` 的配置 / 环境变量约定
5. 项目 README 的 "Publishing" / "Release" 段落

若项目有明确的 publish script，优先复用；若没有，按各平台默认最小流程准备。

### 产出分平台 payload

每个目标平台输出：

```md
### <平台名>

- build 命令: <如 `pnpm build:chrome` 或 `web-ext build -s dist/chrome`>
- 产物 zip: <路径>
- manifest 版本: <值>
- 商店字段:
  - name: ...
  - description: ...
  - category: ...
  - permissions justification: ...
  - screenshots: [<路径>, ...]
  - promo tiles: [<路径>, ...]
- 提交方式: <CLI 命令 or UI 步骤>
- 审核预期时间: <依平台>
```

### 默认不自动上传

除非用户明确说「自动上传」「一把梭直接发」「调 API 提交」，否则：

- **不要**执行 `chrome-webstore-upload-cli upload`
- **不要**执行 `web-ext sign`（这会实际提交到 AMO）
- **不要**执行任何调用 OAuth token 的上传命令

可以：

- 执行 build（产出 zip）
- 执行 `web-ext lint`（本地校验，无副作用）
- dry-run 命令（若工具支持）

若用户已经明确同意自动上传：

- 使用项目自身的 release script（优先），不要自己拼命令
- 每个平台提交前再次 echo 即将执行的命令，等一次简短确认
- 提交成功后记录审核 ID / 提交 URL

## Step 5: 最终报告

```md
## 扩展发布报告

### 目标
- 扩展: <名称>
- 版本: <版本号>
- 平台: ...

### preflight 结果摘要
- 阻塞: ...
- 建议: ...

### 素材补齐情况
- text-card 生成: ...
- 用户提供: ...
- 非图片缺口: ...

### 提交情况
- <平台>: 已准备 payload / 已提交（<ID>）/ 已跳过（<原因>）

### 遗留
- 待用户跟进: ...
- 审核中: ...

### 下一步建议
```

## Fallbacks

- `ext-publishing-preflight` 不可用 → 手工对照每个平台官方 checklist 做最小集检查，报告中注明降级
- `text-card` 不可用 → 把「可生成图片」转为 user-must-provide，一并交用户
- 项目没有任何 publish script / CI 配置 → 给出每个平台官方 CLI 的最小命令示例，不替用户决定
- manifest 与 package.json 版本不一致 → 停在 Step 2，先让用户对齐版本，再继续
- 用户只发一个平台 → 只输出该平台 payload，不生成其它平台内容

## 禁止行为

- 未经用户明确确认就执行任何实际上传命令
- 用占位图 / 截图蒙混缺失的真实截图
- 文案、permissions justification 瞎编（只能从项目里抽取或明说「待用户填」）
- 跳过 preflight 直接进入 Step 2
- 跳过 Step 3 的用户确认
- 把含糊回应（嗯 / ok 吧 / 随便）当作同意
- 用自己拼的上传命令覆盖项目已有的 release script
- 在用户只要求某一个平台时顺带把其它平台也发了
- 重复追问 preflight 报告 / `manifest.json` / `package.json` / README 中已明确存在的信息（name、version、description、permissions 等）

## 完成判定

同时满足以下条件才算本次编排完成：

- 已运行 preflight（或明确降级）
- 已分流缺失项并生成 / 整理所需素材
- 已输出分平台 payload
- 已收到用户对提交内容的明确确认
- 若用户要求实际上传：已完成上传并记录审核状态
- 已输出最终报告

若用户在 Step 3 或 Step 4 暂停任务，报告中如实记录停在哪一步。
