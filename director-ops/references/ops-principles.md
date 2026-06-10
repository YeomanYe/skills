# Ops Principles — 7 维 Audit Rubric

> 由 `director-ops` 的 Step 6.5 Quality Audit 自跑。沿用 `references/audit-rubric.md` §2 的
> **7 维基线**(不加维度、不减维度),仅按 install / uninstall 两 mode 重定义 1/3/5 锚点。
> 每维 1-5 分,**所有维度必须 [✓] 或 [n/a]**(跳过须写理由,否则按 1 分计入)。< 4 分必出修正建议。

## 锚点说明

每维列 1 / 3 / 5 三个锚点,实际打分落在最接近的锚点上,2 / 4 为中间值。
带 🔻 的描述仅 `uninstall` mode 适用。通用基线锚点见 `references/audit-rubric.md` §2,本文件是
director-ops 的领域特化版(audit 时以本文件为准)。

---

## 1. Scope / 环境探测充分性

> 装 / 卸前对当前系统、目标软件现状、依赖冲突的探测是否够。

**1 分**:
- 只跑一条命令(如只 `which <tool>`)就开干
- 不知道 OS / CPU 架构 / 当前是否已装

**3 分**:
- 跑齐核心 3 项:OS + 版本(`uname -s -m` / `sw_vers`)、目标软件现状(`<tool> --version`)、相关包管理器(`command -v brew npm pipx ...`)

**5 分**:
- 系统 + 架构 + 包管理器全查,并显式检查**依赖冲突 / 已装版本是否被覆盖**
- `uninstall` mode 额外定位残留面:config / cache / LaunchAgent / login items / shell rc / 全局包

---

## 2. 证据来源可信度

> 安装 / 卸载方式的资料来源是否可信、是否做适用性判断。

**1 分**:
- 单一来源(随手搜到第一条命令就用),来源不可信或与当前 OS / 架构不匹配

**3 分**:
- 本地知识库 + 网络资料结合,引用了来源

**5 分**:
- 本地知识库 + 用户提供链接 + 官方文档三方互证,且对每个候选标注**适用性**(OS / 架构 / 版本 / 路径是否匹配当前系统)
- 🔻 uninstall:安装记录只能证明"可能如何装"时,不据此直接删用户数据,只输出候选路径 + 验证方法

---

## 3. 决策证据强度

> "为什么选这个安装方式 / 这个版本 / 删这个路径"是否有可核对的定位引用。

**1 分**:
- 结论无定位引用(推荐某包管理器但说不出依据);install 只收集到一种方式就拍板

**3 分**:
- 部分决策有 `[command:输出]` / `[url]` / `[file:line]` 引用

**5 分**:
- 每条决策都有可核对引用;install **枚举所有官方 / 高可信候选方式**(Homebrew / 官方 tap / 官方脚本 / npm / pipx / cargo / direct binary / `.pkg` / `.dmg` / cask / Docker),逐项标注来源可信度、OS/架构适配、是否需 sudo/交互、PATH 影响、升级方式、卸载方式、可复现性、主要风险,再给推荐理由

---

## 4. 用户确认清晰度(本 skill 重定义:基线"可执行性"→ 破坏性操作的用户 gate)

> 用户是否在看到完整计划后明确确认,且理解 sudo / 破坏性影响。

**1 分**:
- 模糊确认或**完全跳过确认**就执行破坏性操作(sudo / 改 PATH / 写全局配置 / 删数据)

**3 分**:
- 用户明确同意("go" / "装" / "卸" / "ok 开始")后才执行

**5 分**:
- 用户明确同意,且计划已清楚展示**每步类型(全自动 / 半自动 / 全手动)+ 风险 + 来源**,用户**理解 sudo / 破坏性影响**(install:候选对比 + 推荐理由 + 预估时间 + 磁盘 + 是否重启;uninstall:即将删除项 + 影响范围 + 是否删配置/数据 + 备份规划)

**红线**:维度 4 = 1 → `failed`(没用户确认就破坏性操作)。

---

## 5. 执行 / 产出成功率

> 执行过程对失败的处理纪律。

**1 分**:
- 失败一步盲目重试(尤其 ≥ 3 次)、无错排、盲删数据

**3 分**:
- 有失败但**立刻停下报告**,不擅自重试、不盲删

**5 分**:
- 全部步骤成功,或失败时定位精准(给出失败命令 + 退出码 + 可能原因 + rollback);
  🔻 uninstall 先按计划备份(记录备份时间 / 路径 / 内容摘要)再执行,**不混用安装方式**,不只删二进制留后台服务/LaunchAgent

---

## 6. 验证完整性

> 装 / 卸是否真正验证到位,而非"退出码 0 就宣告完成"。

**1 分**:
- 只验 1 项(如只看 `brew install` 退出码),或完全不验

**3 分**:
- 验证主路径:install 跑 `<tool> --version`;uninstall 跑 `command -v <tool>` 应无输出

**5 分**:
- install:主命令(`--version`)+ `which`(PATH 生效)+ **残留扫描** + 一个最小功能 smoke 全覆盖;PATH 没生效时明确告诉 source 哪个 rc + 建议加到 `~/.zshrc`
- 🔻 uninstall:主命令移除 + `brew list --formula/--cask` 无列 + `/Applications/` / LaunchAgent / login items / 后台服务已清 + 备份文件可见;**只有验证通过后**才删残留数据

**红线**:维度 6 = 1 → `partial`(没验证就宣告完成)。

---

## 7. 可追溯 / 知识库沉淀质量

> 写入 `~/Documents/knowledge/<tool>-{install|uninstall}.md` 的记录能否让未来 agent 反推复现。

**1 分**:
- 没写知识库,或"装了 foo,完成"这种垃圾记录

**3 分**:
- 填了 `references/record-template.md` 模板(环境 / 日期 / 方式 / 步骤 / 验证)

**5 分**:
- 记录含**日期 + 版本 + 为什么选这个版本 + 解决了什么依赖冲突 + PATH 加在哪一行 + 验证命令 + 怎么回滚 + 参考链接**;
  🔻 uninstall 额外含:备份路径 + 删除的数据路径 + 卸载来源。标准:**另一台机器带这份记录 10 分钟能原样复现**

---

## Aggregate 评分

aggregate = 7 维**算术平均**(`sum / 7`,`[n/a]` 维度不计入分母但须写跳过理由)。
**禁止**几何平均 / 加权稀释短板(走下方红线降级,不靠权重粉饰)。

| Aggregate | Verdict | 行动 |
|---|---|---|
| ≥ 4.5 | `installed-clean` / `uninstalled-clean` | 完成,记录知识库 |
| 4.0-4.4 | `installed-with-warnings` | 完成但在知识库 append 注意事项 |
| 3.0-3.9 | `partial` | 部分完成,明示未完成步骤 + 用户决定是否补 |
| < 3.0 | `failed` | 整体失败,记录失败原因到知识库,回 Step 3 |

(verdict 标签与 `references/audit-rubric.md` §4.1 的 director-ops 列对齐。)

## 红线触发(§3 通用之外的本 skill 自定义)

- 维度 4 = 1 → `failed`(没用户确认就执行破坏性操作 sudo / 改 PATH / 写全局配置 / 删数据)
- 维度 6 = 1 → `partial`(没验证就宣告完成,把锅推给下游)
- 通用红线沿用 `references/audit-rubric.md` §3(维度 3 = 1 无引用 / 维度 4 = 1 含破坏性操作 → 最低档)

## Reference 用例

- ✅ / ❌ 锚点对应的正反例见 `tests/cases.md`
- 记录模板(装 / 卸两套)见 `references/record-template.md`
