# experiment/meta-skill — STATUS

> Cron 唤醒后**第一件事:Read 本文件 → 决定续作业从哪开始**

## 全局约束
- **截止时间**:2026-06-03 13:30 CST(已超过 → 自停 + cc-connect cron del)
- **预算**:每次 wake 跑 30-40 min 工作量,看 5h 额度
- **5h 额度自检**:`cd ~/Documents/projects/node-scripts && node dist/claude-usage/index.js --json` → 解析 `fiveHour.percent`,**> 95% 直接 halt** 本轮(防触发 hard limit;user 2026-06-02T23:38 调高阈值)
- **分支**:`experiment/meta-skill`(不动 main)
- **工作目录**:`/Users/falcom/Documents/projects/skills/`
- **audit 报告**(已生成,P0/P1/P2 内有):
  - `.experiment-state/skill-audit-flow.md`
  - `.experiment-state/skill-audit-director.md`
  - `.experiment-state/skill-audit-misc.md`

## 优化顺序(用户敲定)
1. ✅ **hat 优化 — 完成 @ 06-03 01:10** (commit 84cb935;P1 precedence + P1 _shared cite + P2 lateral-no-propose + 4 new test cases)
2. ⏳ **meta-skill 新建** ← 下一个
3. ⏳ experience-summary 优化
4. ⏳ flow-*(7 个)优化
5. ⏳ director-*(5 个)优化

## 当前进度

### Phase: 1 — hat 完成,准备 meta-skill
- 2026-06-02T23:25 CST:smoke test cron 唤醒验证通过
- 2026-06-02T23:30 CST:setup 完成(branch + STATUS.md + 真 cron 配好)
- 5h 额度 94% 用完(00:49 重置)→ 当晚不做事,等 cron 在 00:55 唤醒
- 2026-06-03T00:55 CST:cron 唤醒,5h=21%
- 2026-06-03T01:10 CST:**hat 优化完成**(commit 84cb935)
  - SKILL.md 221→244 lines:加 main-skill precedence 段、Output Contract cite _shared、横向不主动 propose
  - tests/cases.md 617→686:加 B1-B4 用例
  - skill-doctor: 0 err / 12 warn(可后续清,non-blocking)

### Next Action(下次 wake 第一步)
1. 读本 STATUS.md
2. 跑 `claude-usage --json` 看 5h%
3. 看当前时间是否过 06-03 13:30(过了 → 自停 + 删 cron + push 分支 + cc-connect 通知 user)
4. 否则:看 "Current Task" 段
5. 完成一块工作 → 写 commit + 更新本 STATUS.md → halt

### Current Task: meta-skill 新建(未开始)

**目标**:per-project skill 自动配置 orchestrator。探测项目类型 + 阶段,生成 skill manifest(给 skillshare 用),让 agent 按项目动态加载 skill。

**用户敲定的设计要点**(2026-06-02 对话):
- 不引入"常驻 skill"概念(用户通过 skillshare 手选)
- meta-skill 输出 = skill manifest(给 skillshare 读)
- 项目阶段:bootstrap / dev / debug / finish 4 阶段(可后续细化)
- 阶段切换通过 exp-sum 监测信号触发,不新发明
- 高风险动作(直接改 .skillshare/ 启用项)必须 user gate

**最小可行 skeleton**:
- `meta-skill/SKILL.md`:Required Workflow 6 步
  1. 探测项目(技术栈 / 阶段 / 历史 incident / 项目规则)
  2. 推断阶段 + 候选 skill 集
  3. 输出 manifest JSON
  4. (可选)显示给用户 + 等确认
  5. 落地到 `.claude/skills-manifest.json` 或 `<project>/.skillshare/enabled.txt`
  6. 记录 manifest 版本 + 上次同步时间
- `meta-skill/references/project-detection.md`:技术栈 / 阶段探测规则
- `meta-skill/references/manifest-schema.md`:manifest JSON schema
- `meta-skill/tests/cases.md`:基础用例
**输出**:
- 新建 `meta-skill/` 目录
- commit "feat(meta-skill): initial scaffold per user-approved design"
**完成标准**:
- SKILL.md 含 description / When to Use / Workflow / Output Contract / Red Flags / Relationship
- manifest JSON schema 明示
- 4 个阶段(bootstrap/dev/debug/finish)候选 skill 集表
- 至少 3 个 test cases(技术栈探测 / 阶段推断 / 高风险落地 gate)
- skill-doctor 0 err

## Halt 协议(每次工作完都做)
```bash
cd ~/Documents/projects/skills
git add -A
git commit -m "<msg>"
# 不 push (等所有 task 完才 push)
# 更新 STATUS.md
# 如果已到 06-03 13:30 → 删 cron + cc-connect 通知
```

## Halt 触发条件(任一)
- 当前时间 ≥ 2026-06-03 13:30 CST
- 5h 额度 > 95% used
- 5 个 task 全部 completed
- 异常(git 冲突 / 无法解析 audit / 上下文不足)

## cc-connect 通知 user 时机
- 5 个 task 全完成
- Halt 触发(deadline / 异常)
- 中途有 user 需要决断的高风险动作
