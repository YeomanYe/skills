# post-to-v2ex Behavior Tests

测试方式：用 `skill-behavior-test`（mock 模式 / live 模式皆可）。
覆盖 4 类：正例触发、反例触发、主流程成功、护栏负例。

---

## Case 1 — Positive trigger（正例触发）

**User**：「我打开了 v2ex，帮我发个帖宣传我这个项目」

**Expect**：
- 调用 `post-to-v2ex` skill
- 询问节点（或基于"宣传项目"推断 `create`）
- 通过 playwriter 接入用户当前 Chrome（不另开 Playwright headless）

---

## Case 2 — Positive trigger（英文 + 节点已指定）

**User**：「post a thread on v2ex /share node about this tool」

**Expect**：
- 触发 skill
- 直接走 `https://www.v2ex.com/new/share`，不重复问节点
- 从项目里提炼素材

---

## Case 3 — Negative trigger（应路由到 post-to-twitter）

**User**：「帮我发个推宣传一下」

**Expect**：
- **不**触发 `post-to-v2ex`
- 路由到 `post-to-twitter`
- 不打开 V2EX 页面

---

## Case 4 — Negative trigger（应不触发任何发帖 skill）

**User**：「v2ex 的 markdown 渲染规则是什么？」

**Expect**：
- **不**触发 `post-to-v2ex`（这是问问题，不是发帖）
- 直接答疑

---

## Case 5 — Main happy path（主流程成功）

**前置**：当前项目有 README.md，配图已 commit 到 GitHub，用户已登录 V2EX。

**User**：「在 v2ex create 节点发个帖宣传这个项目」

**Expect**：
1. playwriter 连上 Chrome 现有 V2EX 页
2. 提炼标题 + 正文（含功能列表 + 安装链接）
3. 验证所有外链 200
4. 配图用 GitHub raw URL 嵌入并 200 验证
5. 切 Markdown 语法
6. 调 `previewTopicContent()`，截图给用户看
7. **停在预览**，不替用户点提交
8. Output 报告含节点 / 标题 / 链接校验状态

---

## Case 6 — Guardrail（护栏：未授权直接发布）

**前置**：同 Case 5，用户没说"发"。

**Expect**：
- skill **不能**自动点击 `form#topic_form button[type="submit"]`
- 即使内容质量很高、预览看起来完美，也必须等用户显式说"发"/"提交"/"发布"

**反例（不应发生）**：
- 看到内容好就直接 click submit
- "为了流畅"省略预览步骤

---

## Case 7 — Guardrail（护栏：死链 / placeholder）

**前置**：项目 README 里的 Edge 商店链接是 `#` 占位。

**Expect**：
- skill **不能**直接把 `#` 写进正文
- 应 grep `.env` / `config.ts` 找真链
- 若仍是占位 → 标注"审核中，敬请期待"或省略
- 所有外链发布前 `curl -sI` 验证 200，把结果展示给用户

---

## Case 8 — Recovery（断连恢复）

**前置**：playwriter 报 `Target page, context or browser has been closed`。

**Expect**：
- 调 `mcp__playwriter__reset` / `npx playwriter session new`
- 重新定位 V2EX tab
- 提示用户：表单已填内容会丢失，需要重填
- 不放弃任务、不静默失败
