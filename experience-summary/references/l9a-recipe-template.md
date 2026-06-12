# L9a Recipe Template —— mem unblock 分类写作骨架(原 unblock-recipes)

> experience-summary 判断树命中 Q9a(跨 agent 卡壳-解法) 时,按本模板输出可直接 copy-paste 到
> `~/Documents/projects/skills/mem/data/unblock/<slug>.md` 的骨架。
> 主体 SKILL.md 不再内嵌完整骨架,避免主文件膨胀。

## 何时使用

experience-summary 路由到 L9a 时:
- 用户/agent 把本骨架填值后落盘到 `mem/data/unblock/<slug>.md`(2026-06-12 起,原 `unblock-recipes/recipes/` 路径已迁入 mem)
- **必须同步更新** `mem/INDEX.md (unblock 段)` 两处(见末段"INDEX 同步硬约束")

## Recipe 骨架(用户填值后 copy-paste)

```md
---
slug: <kebab-case-3-30-chars>            # 跟文件名一致
symptoms:                                  # INDEX 索引用关键词(≥3 个,具体到 agent 真会读到的错误信息片段或行为描述)
  - "<具体症状词1>"
  - "<具体症状词2>"
  - "<具体症状词3>"
first_seen: <today YYYY-MM-DD>
last_hit: <today YYYY-MM-DD>
hit_count: 1
tags: [<tag1>]                            # 至少 1 个,选自 mem/INDEX.md (unblock 段) "按 tag 分类"段已有词典
---

## <slug> — <一句话症状,≤30 字>

### 症状信号
<agent 怎么识别"我在踩这个坑">
- 错误信息典型片段:
- 行为模式:
- 上下文条件:

### 常见错法
<agent 默认会怎么试,为什么不通>(≤3 行)

### 正确做法
<实际走得通的路,带具体命令 / 代码 / 配置>(≤80 字 / ≤5 行)

### 出处
- 首次发现: <today> / 在 <什么场景 / 哪个项目 / 哪个 skill>
- 复现: 1 次
```

## 字段说明

| 字段 | 必填 | 约束 |
|---|---|---|
| `slug` | 必填 | kebab-case,3-30 字符,与文件名一致 |
| `symptoms` | 必填 | ≥3 条,要是 agent 真会读到的错误信息片段或行为描述,不要写抽象总结 |
| `first_seen` / `last_hit` | 必填 | YYYY-MM-DD |
| `hit_count` | 必填 | 首次 = 1,后续复现 +1 |
| `tags` | 必填 | ≥1 个,从 `mem/INDEX.md (unblock 段)` "按 tag 分类"已有词典选 |

## 四段正文要求

1. **症状信号**: 必须含"agent 怎么识别"——错误信息典型片段 + 行为模式 + 上下文条件三选二
2. **常见错法**: ≤3 行,说明 agent 默认会怎么试 + 为什么不通(没有这段 = 读者不知道这条 recipe 解决了什么误区)
3. **正确做法**: ≤80 字 / ≤5 行,必须带具体命令 / 代码 / 配置(空话 = 召回时无法直接执行)
4. **出处**: 首次发现日期 + 场景(项目名 / skill 名),用于后续 hit_count 累计

## INDEX 同步硬约束(experience-summary 输出时必须同步提示用户)

落盘 recipe 文件**还不算入册**,必须同步更新 `mem/INDEX.md (unblock 段)` 两处:

1. 在"按 tag 分类"对应分类下追加 `- <slug>` 一行
2. 在"按 symptom 关键词反查"表为**每个** symptom 追加一行(同 slug 可重复)

**未同步 INDEX = 等价于没入册**(召回时找不到,等于白写)。

commit 到中心后,pre-commit hook 跑 skill-doctor 自动检查 frontmatter 完整性。

## 不替代

- `flow-skill-dev`(那是写 skill 本身,不是写错题本条目)
- `superpowers:brainstorming`(那是发散探索)
- retro / post-mortem 会议(那是更重的复盘)
