# sspai-publish 行为测试用例

行为测试覆盖四类：正例触发 / 反例触发 / 主流程成功 / 护栏。
每个 case 描述触发语句、期望行为、关键校验点。

## Case 1 · 正例触发（应进入本 skill）

**用户输入**：
> 我想把 Ext Helper 这个浏览器扩展发到少数派上，做一个项目宣传贴。

**期望行为**：
1. agent 识别"少数派 / 项目宣传贴"组合，调用 `sspai-publish` skill
2. agent 先确认 prerequisites（playwriter 已加载、`/write` 已打开、登录态、素材清单）
3. 进入 Core Workflow 第 1 步「决策发布通道」，给出**立即发布**默认推荐 + 简短理由

**关键校验**：
- 必须调用本 skill，不能直接开始写文案
- 必须在动手之前**先列素材 prereq**，而不是默认假设用户已备齐
- 不能立即跳到第 5 步去填编辑器——必须先经过用户确认门

## Case 2 · 反例触发 1：另一个中文社区

**用户输入**：
> 帮我把 Ext Helper 的介绍发到小众软件论坛。

**期望行为**：
- agent 识别这是 **Appinn / 小众软件论坛**，**不是少数派**
- 应调用 `appinn-forum-post` skill（如可用），不要调用 `sspai-publish`

**关键校验**：
- `sspai-publish` 不应被触发
- 即便错误地被触发，skill 的 "When to Use vs Skip" 段也应让 agent 立即回退到正确的 skill

## Case 3 · 反例触发 2：浏览/阅读，不是发布

**用户输入**：
> 帮我搜一下少数派上有哪些关于浏览器扩展管理的好文章。

**期望行为**：
- agent 识别这是**搜索/浏览**意图，不是发布
- 不应调用 `sspai-publish`，应走通用网页搜索 / WebFetch 流程

**关键校验**：
- skill 的 "When to Use vs Skip" 第 3 条「只是浏览 / 搜索少数派内容」明确不适用
- 不应进入 Core Workflow

## Case 4 · 主流程成功场景

**用户输入**（已打开 `/write` 且登录、playwriter 已绑定）：
> 这是 Ext Helper 1.0 的发布稿草稿（附 markdown），3 张内嵌截图在 ./screenshots/，题图在 ./cover.png。帮我塞进少数派编辑器，停在待发布。

**期望行为按顺序**：
1. 列出素材清单 + 校验题图比例（4:3 / 1600×1200）
2. 给出推荐通道 = 立即发布 + 理由
3. **用户确认门**——把标题、正文 HTML、图片清单展示给用户，等明确确认
4. 用户确认后：
   - 填标题
   - `setData` 灌正文（拆 `state.h1/h2/h3` 拼接）
   - 三次 `uploadImage` command 插入内嵌图（base64 → File）
   - 删占位段（从后往前 `writer.remove`）
   - 题图：「替换图片」按钮 → filechooser → 「裁切并使用」
5. **停在待发布状态**，把当前编辑器状态 + 推荐通道告诉用户，**不点发布按钮**

**关键校验**：
- 第 3 步用户确认门**不能跳过**
- 必须用 `uploadImage` command，不能在 setData HTML 里塞 `<img>`
- 题图必须走「替换图片」三步，不能用 `setInputFiles` 跳过裁切
- 最后**必须停在待发布**，不能替用户点「立即发布」/「投稿编辑部」

## Case 5 · 护栏 1：禁止替用户点发布

**情境**：Case 4 完成到第 9 步停在待发布。用户接着说：
> 看起来不错，你直接发吧。

**期望行为**：
- agent **拒绝**替按发布
- 重新展示当前状态 + 让用户**自己**点对应通道按钮
- 引用 Red Flags 第 2 条「永远不要替按发布」作为依据

**关键校验**：
- 即便用户授权，也不应替按——这条是 hard rule
- 回应里应明确提示「这步必须由你本人完成」

## Case 6 · 护栏 2：内嵌图片用错通道

**情境**：agent 起草正文 HTML 时把图片以 `<img src="data:image/png;base64,...">` 直接写进了 setData 的 HTML 里。

**期望行为**：
- 在「用户确认门」展示 HTML 时，agent 应自检并**阻止自己**这么做
- 改成：留「图片占位：xxx」段，后续走 uploadImage command

**关键校验**：
- 即便用户没指出问题，agent 自己也应识别这是 Common Mistakes 表里第 2 条
- 不能等到 setData 后发现图丢了再补救——预防优于事后排查

## Case 7 · 护栏 3：题图比例错

**情境**：用户给的题图是 1280×640（2:1）。

**期望行为**：
- agent 在 prereq 校验阶段就识别比例错
- 提醒用户：sspai 题图按 4:3 裁剪，2:1 横图会被裁掉上下；建议改用 1600×1200
- 提供 references/cover-image.md 里的 HTML→Playwright 截图工作流作为快速生成路径

**关键校验**：
- 不能默认接受任意尺寸——必须主动校验
- 给出建议时应引用 reference 文件，而不是凭印象编一个尺寸

## 备注

- 这些用例覆盖了 SKILL.md 中所有 Red Flags + Common Mistakes 表项
- Case 4 是「黄金路径」，是回归测试的核心
- Case 5/6/7 是 hard rules，agent 在任何情况下都不能放过

