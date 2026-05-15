# UI Review Checklist

UI 任务（GOAL.md `is_ui_task: true`）激活的强制 checklist。来自实战经验沉淀（Codex UI 循环改造案例）。

## 一、状态走查矩阵（必须覆盖，不能只看默认）

### 通用状态（所有 UI 都要走）
- [ ] 默认未操作状态（normal）
- [ ] 已操作但无反馈
- [ ] 操作成功反馈（短暂浮层 / 状态切换 / status pill）
- [ ] 操作失败反馈
- [ ] 加载中
- [ ] 空状态（无数据）
- [ ] 错误状态（API 失败 / 网络断）

### 数据多寡
- [ ] 0 条
- [ ] 1 条
- [ ] 少量（2-3 条，如重复提醒）
- [ ] 大量（滚动 / 分页边界）

### 视口
- [ ] 默认尺寸
- [ ] 最小尺寸（移动 / 窄 popup，如 400×620）
- [ ] 最大尺寸（宽屏 / 大 popup，如 1920×1080）
- [ ] 滚动到底部（弹窗内容超出视口的情况）

### 配置/选项分支（如果存在）
- [ ] 默认配置
- [ ] 用户改了某项后的渲染
- [ ] 极端配置（自定义 model 名超长 / API key 看不见 / URL 超出等）

### Popup 专属（如果是 popup 形态）
- [ ] 弹窗本身不超出视口
- [ ] 内容区域内部滚动而不是撑出
- [ ] 底部 footer 永远可见
- [ ] URL / API Key / 模型名等底部字段可达

## 二、截图三件套（强制）

### 1. 即时发送
每个 milestone / mini-review / final review 的截图必须**立刻**通过 cc-connect 发 IM。
- ❌ 禁止：批发，等所有截图都齐了再统一发
- ✅ 正确：每张截到立刻发，附带"这是第几轮 / 哪个状态 / 验证什么"说明

### 2. 肉眼校验文件名 ≠ 内容
**必须在发送前用 view_image 看一遍**。常见 bug：
- `normal-saved.png` 实际显示设置弹窗
- `duplicate.png` 只显示页面顶部没有重复信息
- 滚动截图实际截到了首页顶部

watcher 立刻发 IM 后，把所有截图路径写入 `pending-review-images.txt`。orchestrator 下次被人 ping 唤醒时**批量补校验**。发现错位 → 单独发"勘误"消息 + 重新截图。

### 3. 收尾发"历史最高分轮次"截图
最终 commit 的是 HIGHEST_TAG 不是 HEAD。
所以最终 IM 推送必须发**历史最高分那轮**的截图，明确说明：
- "这是 round-X，aggregate=Y.Y，是历史最高分版本"
- "为什么选这一轮：[reason]"
- "如果最后一轮不是最高分：最终交付已回退到最高分版本"

不要只发最后一轮截图。

## 三、UI 任务专属评分维度（默认建议加到 EVAL.md）

详见 `references/score-rubric-extensions.md`。常用：

- **Layout Stability** — 反馈、header、footer、滚动区域是否稳定（成功反馈不能顶开 footer / 不能遮挡按钮）
- **Small Popup Density** — 小空间是否紧凑但不拥挤（footer 不膨胀 / 重复提醒紧凑表达）
- **Interaction Priority** — 高频操作优先（保存按钮在底部主位）/ 低频配置收起（AI 设置不常驻）
- **Visual Polish** — 间距、层级、图标语义、按钮平衡是否自然
- **Functional Safety** — 保存、更新、搜索、设置、滚动、验证脚本是否安全
- **State Consistency** — 数量承诺与可见内容一致（"发现 2 条" → 必须看见 2 条而不是 1 条 + "另有 1 条"）

## 四、同分时的硬规则裁决

reviewer 对 round-A 和 round-B 都打了 4.6 综合分，但：
- round-A 的 toast 短暂覆盖标签添加区域
- round-B 用固定宽度 status pill，不遮挡控件

按当前 skill **必须**：
- 优先选 round-B（无遮挡 = 符合"硬规则风险"段）
- 即使分数相同，有 layout / 状态 / 数量承诺等硬风险版本不优先
- 同分版本被选为新基准后，no-improvement 计数从该基准重新算

硬规则风险清单（按 GOAL.md `STOP-CONDITIONS.md` 中的"hard-rule risks" 段，UI 任务必填）：
- 遮挡控件 / 顶开 footer / 撑出视口
- 数量承诺 ≠ 可见内容
- 状态混淆（saved 普通态 vs 真实保存成功反馈区分不开）
- 关键操作不可达（弹窗滚不到底）
- 一致性破坏（明明的列表项格式突然变化）

## 五、reviewer 必须实际跑项目（不能只看 diff）

reviewer-prompt.md Step 4 已经强制。这里强调几个常见绕过：
- ❌ "test.txt 全绿就行" → 编译过 ≠ 跑得起来
- ❌ "Goal 截过图了" → Goal Codex 可能只截了好看的状态
- ❌ "看 diff 改动很合理" → diff 看不出运行时白屏

reviewer 必须：
1. `pnpm dev` / `npm start` / `cargo run` 启项目
2. 通过 chrome MCP / playwright 实际点击
3. 自己截图到 `review-input/screenshots/reviewer-fresh/`
4. 对比 Goal 的截图——如果 Goal 截的看着完美但 reviewer 截的有问题 → Must Fix（Goal 截图作弊）

## 六、从用户问题抽象评分维度（动态扩展）

用户在 IM 中提出具体问题时，**不要只当单点修复**，要抽象成可复用、可打分的评分维度。

例：
- 用户："成功效果不应该影响布局" → 抽象为 `Layout Stability`
- 用户："低频信息放配置里" → 抽象为 `Information Frequency Priority`
- 用户："顶部不能折行" → 抽象为 `Header Stability at Small Width`
- 用户："不要大留白" → 抽象为 `Small Space Density Control`

orchestrator 在 IM 收到这类反馈后：
1. 抽象出维度名 + rubric 描述
2. 追加到 EVAL.md `Reviewer Rubric` 段（含分值范围 1-5）
3. 写到 STATUS.md `## Human Feedback` 段（Goal 下个 milestone 读到）
4. 下一轮 mini-review / final review 自动按新维度评

## 七、数量承诺与可见内容一致

UI 明确写"发现 N 条"时，必须展示对应数量的核心内容：
- N ≤ 2：直接全部显示
- N > 2：显示前 2 条 + "另有 N-2 条"
- 空间不够：必须有展开 / 查看全部入口

不能让用户看到"发现 2 条"后只能看见 1 条——会自然追问"还有一条呢"。

验证脚本应断言 N 条标题都出现在面板文本中，而不是只检查"另有 1 条"。
