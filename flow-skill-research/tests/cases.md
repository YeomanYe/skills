# Orchestrating Skill Research Test Cases

## Case 1: 技术栈 Skill 调研

- 输入: “查一下跟 preact、fresh 技术栈相关的 skill 有哪些，使用 find-skills。”
- 预期触发: `orchestrating-skill-research`，并调用或遵循 `find-skills`。
- 预期行为: 先检查本地已安装 skill，再至少搜索 `preact`、`fresh`、`deno frontend` 等变体，区分直接匹配和相邻匹配。
- 失败信号: 跳过本地检查；只跑一个关键词；把 Fresh 旧版本候选当作无风险推荐。

## Case 2: 查看候选内容

- 输入: “给我看一下这些 skill 中写了哪些内容。”
- 预期触发: `orchestrating-skill-research`。
- 预期行为: 读取候选真实 `SKILL.md` 或等价源文件，再总结触发条件、核心流程、资源、风险，以及哪些具体条目满足用户需求。
- 失败信号: 只复述搜索结果、安装量或仓库名；只说“相关”但没有列出满足需求的证据点。

## Case 3: 安装边界

- 输入: “帮我找一下重构或者组件拆分相关的 skill。”
- 预期触发: `orchestrating-skill-research`。
- 预期行为: 只调研和推荐安装命令，不执行安装。
- 失败信号: 未经用户明确要求直接运行 `npx skills add`。

## Case 4: 明确安装

- 输入: “就第一个吧，到全局。”
- 前置上下文: 上一轮已经给出排序候选。
- 预期触发: `orchestrating-skill-research` 可继续处理安装动作。
- 预期行为: 只安装上下文中第一个候选，使用 `npx skills add ... -g -y`，报告 warning 和安全扫描结果。
- 失败信号: 安装多个候选；自动同步到 `~/.config/skillshare/skills/`。

## Case 5: 无可靠候选

- 输入: “有没有非常特定内部平台的 skill？”
- 预期触发: `orchestrating-skill-research`。
- 预期行为: 若搜索无强匹配，应明确说明未找到可靠候选，并建议直接处理任务或转交 `orchestrating-skill-development` 创建自定义 skill。
- 失败信号: 为了给答案而推荐明显无关或低质量候选。

## Case 6: 误触发保护

- 输入: “用 React 重构这个组件。”
- 预期触发: 不应触发本 skill；这不是 skill 生态调研，而是代码实现任务。
- 预期行为: 使用与 React/前端实现相关的 skill 或直接处理代码。
- 失败信号: 开始搜索 skill 而不是实现用户请求。

## Case 7: skillshare 同步边界

- 输入: “安装第一个到全局。”
- 预期行为: 安装到 agent 全局目录即可，不自动调用 `sync-skills`。
- 失败信号: 把所有安装过的第三方 skill 自动复制进 skillshare source。

## Case 8: 本地已安装强匹配

- 输入: “有没有 PDF 解析相关的 skill？”
- 前置上下文: 本地 `~/.agents/skills/pdf/SKILL.md` 已存在，且 description 覆盖 PDF 读取、文本表格提取、合并、拆分、OCR 等场景。
- 预期行为: 优先报告本地已安装 `pdf` skill，并说明其 description 或正文中哪些点满足 PDF 解析需求；只有本地不足时才继续外部搜索。
- 失败信号: 明明本地已有强匹配却直接推荐外部安装；没有说明 `pdf` skill 中满足需求的具体能力点。

## Case 9: 满足点明细输出

- 输入: “这些重构 skill 哪些点能满足组件拆分？”
- 预期行为: 对每个入围候选分别列出匹配点，例如触发条件、流程步骤、references 或脚本如何支持组件拆分。
- 失败信号: 只输出候选排名；没有说明 skill 内容与需求之间的对应关系。
