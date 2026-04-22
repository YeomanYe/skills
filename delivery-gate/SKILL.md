---
name: delivery-gate
description: Use when a task is about to be claimed complete and you need a project-agnostic pre-delivery review gate that (1) reviews code quality beyond lint/build, (2) judges whether Playwright screenshots or recordings are required, (3) routes back to writing-plans on must-fix findings or onward to verification-before-completion, and (4) optionally pushes the captured visual evidence back to the IM channel that originated the session (Feishu/Telegram/Discord/WeChat/QQ), falling back to gif when the IM channel does not accept video. 用于任务完成前的通用交付审查闸门：做超出 lint/build/test 的项目专属审查、按规则判定 Playwright 截图与录屏要求、按结果回流 writing-plans 或继续 verification-before-completion，并在来源为 IM 通道（飞书/Telegram/Discord/WeChat/QQ）时回传截图和视频，视频不支持时降级为 gif。
---

# 通用交付闸门

## 概览

这个 skill 是完成声明之前的审查闸门。它不替代最终验证，只决定当前工作应当：

- 回流到 `writing-plans` 进入下一轮修复，或
- 继续进入 `verification-before-completion` 做最终验证，或
- 在 IM 来源的会话中，完成 gate 判定后把视觉证据回传到来源频道

它是项目无关的。任何项目内的专属 gate 存在时，本 skill 让位给项目 gate。

## 适用时机

- 本仓库的功能、重构或缺陷修复准备被报告为完成
- 需要做超出 lint、build、test 的审查
- 需要判断本次任务是否要求 Playwright 走查截图或录屏
- 本次会话来源是 IM，需要把截图与录屏回传到原始频道

以下场景不要使用：

- 前期需求发散或 brainstorming
- 代码尚未存在时的原始实现规划
- 项目已有专属 delivery gate（本 skill 应让位给项目 gate）

## 项目规范适配

本 skill 不绑定特定项目，使用前应自动探测项目规范入口。

优先按存在顺序读取：

- `CONTRIBUTING.md`
- `AGENTS.md`
- `RULE.md` 或 `RULES.md`
- `docs/coding/`, `docs/ui/`, `docs/ai-guide/`
- `.agents/skills/*-delivery-gate/SKILL.md`（项目级 gate）

若检测到项目级 delivery gate skill，必须在输出中显式说明并让位给项目 gate，不重复执行。

## 必要输入

使用前应先收集：

- 任务目标
- 本次修改文件（git diff）
- 相关的 plan、handoff、design doc
- 当前会话中任何提到验证或录屏要求的 skill 输出
- 环境变量 `CC_SESSION_KEY`（判断是否为 IM 来源）

## 两阶段闸门

### 第一阶段：规范与架构审查

基于 diff 审查项目规范中 lint 通常无法证明的问题。

重点关注：

- 应抽离却仍被硬编码的常量、文案、选项或配置
- 未复用项目现有组件、模式或基元的实现
- 冗余代码、重复分支、复制粘贴逻辑或抽象边界薄弱的问题
- 本可简化的对象映射（语义等价却逐字段透传、而对象展开即可表达）
- 违反项目规范定义的分层边界（route/state/service/API/i18n/UI 等，具体以项目规范为准）
- 涉及 UI 行为变更但未保持项目既有交互模式的实现

每条 finding 都必须包含：

- 文件路径
- 具体问题
- 为什么它会影响本仓库（引用规则条文或既有模式）
- 可执行的修复 todo

禁止输出空泛的风格意见。

### 第二阶段：验证流转判定

第一阶段结束后：

- 只要存在任意 `must-fix`，就停止完成流程并回流到 `writing-plans`
- 若不存在 `must-fix`，才允许继续进入 `verification-before-completion`
- `verification-before-completion` 通过后的下一 skill 由项目决定；若项目未定义，默认为 `committing-clean-changes`

`should-fix` 不阻断最终验证，但仍必须被报告。

阶段边界约束：

- 本 skill 的职责是审查、判定与流转，不是代替后续实现环补做证据
- 当已命中任意 `must-fix` 时，必须立即停止后续执行，不得继续尝试截图、录屏或页面交互来"现场补齐证据"
- 命中 `must-fix` 后只允许输出：findings、todo、下一 skill 与回流链

## 严重级别规则

### `must-fix`

满足任一条件即归类为 `must-fix`：

- 违反项目规范文件中的明文规则
- 无正当理由跳过已有可复用组件或既定页面模式
- 将本应位于常量、contract、locale、共享配置中的内容硬编码到业务代码
- 存在语义等价却明显冗余的实现
- 破坏项目规范定义的分层边界
- 引入明显应在合并前收敛的重复结构或臃肿实现
- 需要 Playwright 截图却缺失、放错位置或覆盖不完整
- 需要 Playwright 录屏却缺失、放错位置或覆盖不完整
- 视觉证据未统一由 Playwright 生成，而是来自 `chrome_devtools` 或其他可见浏览器调试工具
- Playwright 走查或录屏未默认使用 `headless` 模式，且无用户明确要求可见窗口演示的证据
- 截图未在预设验收视口的整屏尺寸下获取，或未记录截图视口尺寸
- 录屏未将浏览器视口调整到预设验收尺寸录制，或未记录录屏视口尺寸
- 为联调、验收或录屏临时启动服务时仍占用默认开发端口，或未记录实际 FE/BFF 端口

命中 `must-fix` 的行为约束同前（停止完成、回流 `writing-plans`、不在 gate 阶段补证据）。

### `should-fix`

- 代码本身有效且与项目约束基本一致，可交付
- 问题主要是可读性、局部简化或可选清理
- 保持现状不会实质性破坏项目一致性

## Playwright 截图与录屏判定

截图与录屏需求分层判定。

### 截图判定

若 diff 涉及较大的 UI 变化，即使不要求录屏也应要求截图：

- 页面主区域布局或视觉骨架明显变化
- 整体表格/列表结构明显变化
- 整个弹窗、drawer、二次确认的样式或信息结构明显变化
- 页面级主要信息层级、状态展示或交互反馈明显变化

要求录屏时截图也自动成为必需项。

通常不要求截图：纯逻辑修复、小范围文案变更、轻量样式调整、纯后端变更。

截图清单要求：

- 只写业务层截图点，不写按钮级脚本
- 默认候选项：主页面整屏、关键弹窗打开态、删除二次确认态
- 每个默认候选项先判定 `required` 或 `N/A`；`N/A` 必须写明原因
- 只有"适用但缺失"的默认候选项构成 `must-fix`
- 若默认候选项不足以覆盖本次改动，补充扩展截图清单

### 录屏判定

**第一层：显式要求**
上游 plan、handoff、skill 输出中已明确要求录屏 → 直接判定为必须录屏，本 skill 不得降级。

**第二层：基于变更推断**
无显式要求，但 diff 涉及：新增页面、新增 modal/drawer 流程、新增独立模块、CRUD 主链路行为变化、页面级主交互变化 → 要求录屏。

通常不要求录屏：纯逻辑修复、小文案、轻量样式调整、纯后端变更。

高层业务录屏步骤要求：

- 只写业务层动作，不写按钮级脚本
- 涉及查询区：包含"查询 / 重置"
- 涉及弹窗/drawer：包含"打开 / 完成操作 / 关闭或反馈确认"
- 涉及表格或行操作：包含"进入页面 / 执行操作 / 验证结果"
- 涉及 CRUD 验收：默认顺序为"创建 -> 查询 -> 更新 -> 删除"
- 删除阶段只能删除本次创建的临时测试数据

### 视觉证据统一约束

- 截图与录屏证据只允许使用 Playwright 生成
- 禁止使用 `chrome_devtools` 或其他可见浏览器调试工具充当交付证据
- 默认以 `headless` 模式运行；只有用户明确要求可见窗口 live 演示时才切换有界面模式
- 截图/录屏都必须在同一预设验收视口的整屏尺寸下获取
- 不得只截局部组件替代整屏视口

### 临时端口约束

若为联调、验收或录屏临时启动 FE/BFF 服务：

- 避开默认开发端口
- 按"默认端口 -2、-3、-4..."顺序递减寻找可用端口
- 记录最终实际端口

## IM 证据回传（可选阶段）

本阶段只在会话来源为 IM 时执行。详细命令与降级策略见 `references/im-dispatch.md`。

### 触发条件

环境变量 `CC_SESSION_KEY` 以下列前缀之一开头时触发：

- `feishu:` → 飞书
- `telegram:` → Telegram
- `discord:` → Discord
- `wechat:` → WeChat
- `qq:` → QQ

否则跳过本阶段，在输出中标记 `skipped (non-IM session)`。

### 触发时机

- gate 判定为 `pass`，且截图或录屏证据存在时执行
- gate 判定为 `fail` 时也可执行（把证据回传让用户在手机端看问题），但必须在回传消息中显式标记 `GATE FAILED`

### 回传流程

1. 聚合本次 gate 产物中的截图、录屏文件路径（只收本次新产生的，不要误发历史文件）
2. 按类型分别发送：
   - 图片：直接上传
   - 视频：先尝试原格式（mp4/webm）
3. 视频发送失败时的降级策略（按序尝试）：
   a. 用 `ffmpeg` 转成 gif（10fps, 宽 480px）
   b. gif 仍超限：降 fps 到 8、宽度到 360px 再试
   c. 仍失败：拆成多张关键帧截图发送
4. 对每个 attachment 记录 `sent | fallback-gif | failed` 状态

### 回传约束

- 只推送本次 gate 期间新产生的证据（通过 mtime 或显式传入的路径列表筛选）
- 推送失败不阻断 gate 结论
- 每个附件的发送状态必须写入输出
- 不得把项目敏感路径（如 `.env`, credentials）混入推送

## 输出契约

输出使用以下固定结构：

```md
## 交付审查结果

### 项目规范探测
- CONTRIBUTING/AGENTS/docs 入口命中:
- 项目级 delivery gate 是否存在:
- 若存在：本 skill 让位给 <project-gate-name>，下面内容不再输出

### 范围评估
- 是否属于大范围 UI/交互变更:
- 是否要求 Playwright 截图:
- 是否要求 Playwright 录屏:
- 触发原因:

### 必修项
- [文件路径] 问题描述
  - 规则依据:
  - 影响:
  - todo:

### 建议项
- [文件路径] 问题描述
  - 影响:
  - 建议:

### 验证流转
- 下一步:
- 原因:

### 截图要求
- 是否需要截图:
- 触发原因:
- 默认截图候选项:
  - 主页面整屏截图: required / N/A（原因）
  - 关键弹窗整屏截图: required / N/A（原因）
  - 删除二次确认整屏截图: required / N/A（原因）
- 扩展截图清单:

### 录屏要求
- 是否需要录屏:
- 触发原因:
- 高层业务录屏步骤:
- 数据安全约束: 使用临时测试数据；不得破坏现有数据；若 CRUD，顺序"创建 -> 查询 -> 更新 -> 删除"

### 需向后传递的证据
- 修改文件:
- 删除文件:
- 相关规则、文档或 skills:
- 视觉证据采集方式:
- Playwright 截图路径:
- Playwright 截图视口尺寸:
- Playwright 录屏路径:
- Playwright 录屏视口尺寸:
- 临时使用的 FE/BFF 端口:

### IM 证据回传
- 会话来源: feishu | telegram | discord | wechat | qq | non-IM (skipped)
- 目标频道 ID:
- 附件:
  - <path>: sent | fallback-gif | failed（原因）
```

## 流转规则

- 输出中必须显式写出：
  - 当前 skill: `delivery-gate`
  - 当前结果: `pass` 或 `fail`
  - 下一 skill: `verification-before-completion` 或 `writing-plans`
- 若结果为 `pass`，还必须显式写出：
  - `verification-before-completion` 通过后的下一 skill（项目指定 > 默认 `committing-clean-changes`）
- 禁止只写"我已经做了验证"或"建议后续修复"这种模糊表述
- 如果"必修项"非空：
  - 下一步必须是 `writing-plans`
  - 每条 `must-fix` 都要转成可执行 todo
  - 截图/录屏被要求时，对应 required 项进入 todo
  - 不得在 gate 阶段继续执行截图、录屏或页面操作来补齐证据
  - 必须显式写出回流链路：`writing-plans -> (实现环) -> delivery-gate`
- 如果"必修项"为空：
  - 下一步必须是 `verification-before-completion`
  - 在拿到 fresh verification evidence 之前不得宣称成功

## 常见错误

- 把它当成单纯的 lint 或 build 闸门
- 输出没有文件证据支撑的模糊风格意见
- 放过上游已显式要求的录屏约束
- 新增页面或弹窗却跳过录屏检查
- 把 `must-fix` 混成可选建议
- 在仍有阻断性问题时就继续走最终验证
- 命中 `must-fix` 后仍现场执行截图/录屏补证据
- `pass` 或 `fail` 时不显式点名下一 skill
- 项目存在专属 delivery gate 时仍强行覆盖执行
- IM 会话中不检测 `CC_SESSION_KEY` 就发送，或把历史文件误发
- 视频降级没有尝试 gif 就直接标记 failed
