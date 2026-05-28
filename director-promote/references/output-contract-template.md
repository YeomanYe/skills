# director-promote Output Contract — 完整 markdown 报告模板

> 配合 `references/output-contract-schema.md`(共享基线 JSON schema)使用。
> 主流程要展示给用户 / handoff 给下游时按需 `Read` 本文件描述的 `artifact_path`。
> subagent 派工返回 JSON(基线字段 + 本 skill 扩展字段),**不要在 stdout 复述本 markdown 全文**。

## 本 skill 扩展 JSON 字段

```json
{
  "verdict": "ready | ready-with-fixes | needs-revision | blocked",
  "aggregate": 4.3,
  "must_fix": ["..."],
  "should_fix": ["..."],
  "artifact_path": ".agent/jobs/director-promote-<task-slug>/output.md",
  "platforms": ["twitter", "v2ex", "appinn", "sspai", "producthunt", "chrome-store-assets"],
  "variants_count": 0,
  "dispatch_receipts": [
    {"platform": "twitter", "status": "preview-pending | published | failed", "url": "...", "preview_screenshot": "..."}
  ]
}
```

## 完整 markdown 报告骨架(落盘到 artifact_path)

```md
## Director-Promote Report

### 任务理解
- 用户原话:
- mode 判定: audit | draft | variants | dispatch | recap
- 目标项目: <path / repo URL>
- 目标平台清单: [twitter, v2ex, appinn, sspai, producthunt, chrome-store-assets] 或 not applicable

### 材料探测
- 项目 README / package.json: 命中 / 缺失
- 已有 hero 图: <path> 或 missing
- git remote / version: <info>
- 各平台登录态: twitter=? / v2ex=? / appinn=? / sspai=? / producthunt=?
- playwriter 可用: yes / no

### Question Gate
- 问题数: 0 | 1 | 2 | 3
- 问题清单:
  - Q1: ...(默认值: ...)
- 用户回复: <quote 或 "用默认值">
- 影响的执行决策: <list>

### 证据采集(对照 references/evidence-discovery.md)
- 探测命令: <list curl 200 校验 / find hero 图 / 登录态 check>
- 命中: <list 材料路径 + 平台登录验证结果>
- 缺失: <list 没找到的材料 + 影响>
- 适用性判断: <list 文案是否符合各平台调性 / 链接是否仍 200>
- 降级: <若 materials: missing,明示降级原因>

### 委派情况(哪些 skill 被调度)
- director-design: <做了什么 / 产出路径> | not invoked
- platforms/twitter: <做了什么 / 结果 URL> | not invoked
- platforms/v2ex: <...> | not invoked
- platforms/appinn: <...> | not invoked
- platforms/sspai: <...> | not invoked
- platforms/producthunt: <...> | not invoked
- flow-ext-publish handoff: <素材路径> | not applicable
- 自做(不派工): <自己跑了哪些步骤>

### 遵循的 9 维 audit(**每维必须含 `[平台 URL / 字符数 / 配图路径 / 原文引用]` 佐证**)
- [✓] 标题钩子 — N/5 — `[平台 + 字符数 + 原文]` <对照锚点>
- [✓] 一句话价值 — N/5 — `[原文段引用]`
- [✓] 受众匹配 — N/5 — `[对比 <平台过去 1 个月热帖>]`
- [✓] Hero 视觉冲击 — N/5 — `[配图路径 + 缩略图模拟尺寸]`
- [✓] 图片内容合规 — N/5 — `[扫描清单结果:IP/邮箱/钱包/...]`
- [✓] 图片尺寸适配 — N/5 — `[实际尺寸 vs 平台规范 vs 配图路径]`
- [✓] 长短文齐备 — N/5 — `[各平台版本字数清单]`
- [✓] CTA 引导 — N/5 — `[主链接 + curl 200 校验]`
- [✓] 平台原生感 — N/5 — `[AI slop 词清单扫描结果]`
- **aggregate**: X.X / 5

> 禁止用 "<证据 / 结论>" 等空泛占位符。详见 references/evidence-discovery.md 第 5 段。

### 宣发判断
- verdict: ready | ready-with-fixes | needs-revision | blocked
- diagnosis: <最大问题 1-2 句>
- findings:
  - [must-fix] <平台/材料>: <问题>。影响: <为什么重要>。建议: <怎么改>
  - [should-fix] ...

### Dispatch 结果(仅 dispatch 模式)
- twitter: <URL / draft / failed reason> / 预览截图路径
- v2ex: <URL / preview-pending / failed> / 预览截图路径
- appinn: <topic URL / enqueued + pending_id / failed> / 状态说明
- sspai: <published URL / 编辑器待发布 / failed> / 发布确认状态
- producthunt: <draft URL / scheduled / published / failed> / Launch Checklist 状态

### 产出物
- 文案 / variants / handoff / 预览截图 路径:
- Chrome Store 素材路径(若有):

### Next Step
- 继续 dispatch 下一个平台 / 等用户确认平台 N / 修 must-fix 后重新 audit
- 推荐下一个 mode 和理由

### 明确不在职责内(告知 orchestrator)
- 产品上架应用商店执行(安装包提交) → flow-ext-publish
- 视觉设计判断/出图 → director-design
- a11y/WCAG → web-design-guidelines
- 写生产代码 → director-frontend
```

## 强制字段说明

- **委派情况**段不可写"无 / 简化",必须真实记录哪些 director-* / platforms 子模块被调用
- **9 维 audit** 每维必须 `[✓]` 或 `[n/a]`,每维必须含可核对佐证(URL / 字符数 / 配图路径 / 原文引用),禁止空泛占位符
- **Dispatch 结果** 仅 dispatch mode 输出;其他 mode 整段可省略
- **产出物** 路径必须是绝对路径或 `.agent/promote-handoff/<task-id>/` 起的相对路径
