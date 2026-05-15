# Score Rubric Extensions（扩展评分维度库）

基础 4 维（Correctness / Maintainability / UX / Risk）覆盖大部分通用任务。但具体任务往往需要专属维度才能表达细粒度质量。

本文件列出**预制扩展维度**，Phase 0.1 的 Step 4 由 orchestrator 探测任务类型后**主动建议**，人类可裁剪 / 追加。

每个维度都是 1-5 分制，rubric 描述清楚 1/3/5 三档锚点。

---

## UI 类任务

### Layout Stability — 布局稳定性
反馈、header、footer、滚动区域是否稳定。

- **5/5**：所有反馈用固定空间表达（status pill 不浮层）；header/footer 高度恒定；滚动区独立。
- **3/5**：少数反馈用 toast 浮层，会短暂遮挡控件但不阻断主操作。
- **1/5**：成功反馈顶开 footer / 弹窗内容撑出视口 / footer 上下堆叠。

### Small Popup Density — 小空间密度控制
小尺寸 popup（< 500px 宽）的紧凑性。

- **5/5**：footer 不膨胀；重复提醒紧凑表达；长标签和固定 footer 之间有滚动安全区。
- **3/5**：默认状态稍稀疏，边缘状态正好。
- **1/5**：大块空白；不必要换行；底部按钮上下堆叠；文案啰嗦。

### Interaction Priority — 交互优先级
高频操作 vs 低频配置的位置/可见性。

- **5/5**：高频主操作（保存/更新/搜索）在底部主位 / 顶部 hero 位；低频配置（API key、模型、prefs）收到设置页或顶部小按钮。
- **3/5**：主操作可达但需要 1 次点击进入。
- **1/5**：主操作淹没在配置选项中；用户找不到保存按钮。

### Visual Polish — 视觉打磨
间距、层级、图标语义、按钮平衡。

- **5/5**：8/4 像素栅格；视觉层级 3 级以内；图标 + 文字搭配语义清晰；按钮尺寸/颜色平衡。
- **3/5**：基本规范但有零散偏差。
- **1/5**：随机间距；按钮大小不一；图标无 aria-label。

### Functional Safety — 功能安全
保存、更新、搜索、设置、滚动、验证脚本是否安全。

- **5/5**：所有按钮有防抖；表单有验证；危险操作有二次确认；状态切换有 loading 锁。
- **3/5**：常用功能安全；边缘场景不一定。
- **1/5**：双击保存生成两条；空字段直接提交报错；删除无确认。

### State Consistency — 状态一致性
数量承诺 = 可见内容；多状态间无歧义。

- **5/5**：UI 写"N 条"必看见 N 条核心内容；状态切换无残影；按钮文案准确。
- **3/5**：偶有"另有 N-1 条"摘要但能展开。
- **1/5**："发现 2 条"只显示 1 条 + "另有 1 条"；saved 普通态和真实保存反馈混淆。

### Header Stability at Small Width — 小宽度 header 稳定
最小尺寸下 header 不折行 / 不挤压。

- **5/5**：title 不折行；图标按钮保留 aria-label/title；窄屏下仍清晰。
- **3/5**：title 边缘有截断但能读。
- **1/5**：title 折行成 2 行 / 图标重叠 / 操作按钮挤出。

---

## API / 后端类任务

### API Contract Stability — API 契约稳定性
现有调用方是否仍然能用。

- **5/5**：API 签名零变化；新加字段全 optional；deprecate 流程完整。
- **3/5**：少量 breaking change 但有 migration 文档。
- **1/5**：未通知 breaking change；旧 client 直接报 500。

### Error Path Quality — 错误路径质量
异常情况的处理。

- **5/5**：所有错误有结构化 code / message；retry 策略合理；超时有 fallback。
- **3/5**：常见错误处理 OK；边缘情况吞错。
- **1/5**：吞所有异常；err message 暴露内部细节；无 timeout。

---

## 性能 / 体积类任务

### Bundle Size — bundle 体积
（仅前端 / 库类任务）

- **5/5**：bundle 体积下降 ≥ 10%；无新依赖。
- **3/5**：体积持平。
- **1/5**：体积上升 ≥ 5%；引入大依赖。

### Latency — 关键路径延迟
（仅有 perf benchmark 的项目）

- **5/5**：P95 latency 下降 ≥ 20%。
- **3/5**：持平。
- **1/5**：上升 ≥ 10%。

### Resource Efficiency — 资源效率
内存 / CPU / 网络。

- **5/5**：减少 ≥ 30% 内存或 CPU 占用。
- **3/5**：持平。
- **1/5**：明显上升。

---

## 重构 / 代码质量类任务

### Cyclomatic Complexity — 圈复杂度
函数/方法的圈复杂度。

- **5/5**：所有改动函数圈复杂度 ≤ 8；超长函数被拆分。
- **3/5**：大部分 ≤ 12；少数边缘 case 略高。
- **1/5**：≥ 15 的函数明显增多。

### Test Coverage Delta — 测试覆盖率变化
针对改动的覆盖率。

- **5/5**：改动文件覆盖率上升 ≥ 5%。
- **3/5**：持平。
- **1/5**：下降 ≥ 5%；新代码无测试。

### Documentation Coverage — 文档覆盖率
JSDoc / docstring 覆盖。

- **5/5**：所有 public API 有完整 doc；改动函数文档全部更新。
- **3/5**：主要 API 有 doc；细节文档缺。
- **1/5**：新加函数无任何 doc。

---

## 安全 / 风险类任务

### Security Posture — 安全姿态
（针对涉及输入校验 / 加密 / 认证的改动）

- **5/5**：所有用户输入有 sanitize / validate；密钥不入 log；hash 用 bcrypt/argon2。
- **3/5**：常见路径覆盖；偶有边缘漏报。
- **1/5**：新加 SQL 字符串拼接 / 密码明文存储 / token 入 URL。

### Dependency Hygiene — 依赖卫生
新引入或更新的依赖。

- **5/5**：无新依赖 / 新依赖在 GOAL.md 允许列；版本锁定；无已知 CVE。
- **3/5**：1-2 新依赖但都合理。
- **1/5**：未授权引入；版本未锁；含 high CVE。

---

## 使用方式

Phase 0.1 Step 4 由 orchestrator 探测任务类型：

| 任务类型探测信号 | 建议默认追加的扩展维度 |
|---|---|
| GOAL.md 含 "UI" / "popup" / "页面" / "组件" | Layout Stability + Small Popup Density + Interaction Priority + State Consistency |
| GOAL.md 含 "API" / "endpoint" / "服务" | API Contract Stability + Error Path Quality |
| GOAL.md 含 "性能" / "perf" / "bundle" / "速度" | Bundle Size 或 Latency 或 Resource Efficiency |
| GOAL.md 含 "重构" / "refactor" / "拆" / "清理" | Cyclomatic Complexity + Test Coverage Delta + Documentation Coverage |
| GOAL.md 含 "auth" / "支付" / "加密" | Security Posture + Dependency Hygiene |

人类可：
- 确认建议
- 删除某个不适用的维度
- 追加自定义维度（写法参照本文件格式：维度名 + 1/3/5 锚点）

确认后写入 EVAL.md `Reviewer Rubric` 段；reviewer 后续按全部维度（基础 4 + 扩展）评分。

## 同分裁决用

如果两轮分数相同（aggregate 相等），按本文件中**硬规则风险类维度**优先（如 Layout Stability / State Consistency / Security Posture）裁决——分数相同但硬规则维度更高的版本胜出。
