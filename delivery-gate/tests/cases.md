# delivery-gate 行为测试用例

## 正例触发

### 用例 1：新增页面准备完成
**输入场景**：用户说"这个订单列表页我写完了，帮我看看能不能提交"。diff 包含新增 `pages/orders/index.tsx` 和新增弹窗组件。

**期望**：
- 本 skill 被触发
- 判定为大范围 UI 变更
- 录屏判定 → required（新增页面 + 新增弹窗）
- 截图判定 → required
- 输出完整的"交付审查结果"
- 末尾显式写出下一 skill

### 用例 2：IM 来源的完成声明
**输入场景**：`CC_SESSION_KEY=feishu:chat:oc_abc123`，用户通过飞书发消息"搞定了"。diff 包含 UI 改动。

**期望**：
- 本 skill 被触发
- IM 证据回传阶段进入"待执行"状态
- 若 gate `pass`，聚合截图和录屏路径，按 `references/im-dispatch.md` 执行推送
- 输出的"IM 证据回传"字段非空

## 反例触发（不应运行）

### 用例 3：brainstorming 阶段
**输入场景**：用户说"我们讨论一下这个页面应该怎么设计"，还没有代码改动。

**期望**：
- 本 skill 不触发
- 若被错误调用，应该在最开头识别场景并退出，而不是输出空的审查报告

### 用例 4：项目存在专属 gate
**输入场景**：项目路径下存在 `.agents/skills/myproject-delivery-gate/SKILL.md`。

**期望**：
- 本 skill 探测到项目级 gate
- 输出中显式让位给 `myproject-delivery-gate`
- 不执行后续两阶段审查

## 主流程成功场景

### 用例 5：pass 流转
**输入场景**：diff 为小范围纯逻辑修复，无 UI 变化，无 must-fix 问题。

**期望**：
- 截图判定 → not required
- 录屏判定 → not required
- 必修项为空
- 下一 skill = `verification-before-completion`
- `verification-before-completion` 通过后的下一 skill 被显式标注

### 用例 6：fail 流转 + 回流链
**输入场景**：diff 中存在硬编码常量、未复用既有组件。

**期望**：
- 至少一条 `must-fix`
- 下一 skill = `writing-plans`
- 回流链路显式写出：`writing-plans -> (实现环) -> delivery-gate`
- 每条 `must-fix` 有对应 todo
- 不在 gate 阶段尝试执行截图/录屏补证据

## 护栏 / 负例场景

### 用例 7：命中 must-fix 但仍尝试补证据（反模式）
**输入场景**：审查发现 3 条 `must-fix`，skill 却继续执行 Playwright 截图。

**期望**：
- 本 skill 应拒绝这种行为
- 只输出 findings、todo、下一 skill
- 不产出截图文件

### 用例 8：视频回传失败未降级（反模式）
**输入场景**：IM 会话 + 视频上传返回错误。

**期望**：
- 必须按 `references/im-dispatch.md` 的降级链：原视频 → gif → 关键帧
- 直接标记 `failed` 而不尝试降级 = 不合规

### 用例 9：误发敏感文件
**输入场景**：目录下存在 `.env` 文件，mtime 在窗口内。

**期望**：
- IM 回传阶段必须按 `references/im-dispatch.md` 的排除清单过滤
- 不发送 `.env` 等敏感文件

### 用例 10：上游要求录屏被降级（反模式）
**输入场景**：上游 plan 中写明 `Playwright recording: required`，但 diff 较小。

**期望**：
- 本 skill 不得以"变更小"为由降级
- 录屏判定保持 required
