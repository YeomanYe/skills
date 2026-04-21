# niche-finder 行为测试用例

每个用例都是一段用户输入 + agent 应该如何表现的描述。

## Case 1 — 正例触发：新手问方向

**User input**:
> 我想做一个出海的英文工具站，不知道做什么好。帮我想想方向。

**Expected**:
- agent **触发** niche-finder
- 先问清：方向偏好（工具类 / 内容类）、语言/地区
- 推荐从 51 词根清单入手（引用 `references/word-roots.md`）
- 介绍 8 种方法并推荐 1-2 种（新手 → 方法一 + 方法六）
- 给出具体操作路径（Semrush 筛选条件、`kdroi.py` 路径）
- **不**直接推荐一个词就让用户去做

**Should NOT**:
- 直接说"你做 AI Headshot Generator 吧"（没看数据）
- 跳过四步验证就下结论
- 让用户自己去 Google / Reddit 乱逛

---

## Case 2 — 正例触发：判断单个词

**User input**:
> AI Headshot Generator 这个词值不值得做？月搜索量 8100，CPC $3.5，KD 18。

**Expected**:
- agent 触发 niche-finder
- 先算 KDRoi = 8100 × 3.5 / 18 ≈ **1575**
- 指出 KDRoi 属"极优"区间
- 走四步验证：
  - Step 1（Semrush 数据）：✅ KD<30、Volume>200、意图明确
  - Step 2（Trends）：提醒用户去 `trends.google.com` 查 12 月曲线
  - Step 3（SERP）：提醒用户去 Google 搜索看首页
  - Step 4（CPC）：✅ $3.5 远超 $0.5 阈值
- 输出**做/不做**决策 + 主要理由
- 列出用户还需要验证的两点（Trends、SERP）

**Should NOT**:
- 不算 KDRoi 直接说"值得做"
- 只看 Volume 下结论
- 跳过 Trends 和 SERP 两步

---

## Case 3 — 正例触发：CSV 批量处理

**User input**:
> 我从 Semrush 导出了一批 Generator 相关的关键词到 /tmp/generator.csv，帮我筛排序。

**Expected**:
- agent 触发 niche-finder
- 执行 `python3 ~/.claude/skills/niche-finder/scripts/kdroi.py /tmp/generator.csv`
- 把脚本输出（Markdown 表格）原样贴回用户
- 对 Top 3-5 逐个给出**初步判断**（可能哪些要做、哪些要进一步验证）
- 提醒用户对 Top 候选走四步验证

**Should NOT**:
- 自己重写一个 Python 脚本（必须用 skill 自带的 `kdroi.py`）
- 只看一两个词就下结论，忽略表格里的其他候选

---

## Case 4 — 护栏负例：缺数据下结论

**User input**:
> 我觉得 AI Voice Cloning 很火，这个方向应该很赚钱吧？

**Expected**:
- agent 触发 niche-finder
- **明确拒绝直接下结论**——这是坑一（凭直觉）
- 要求用户提供：Volume / KD / CPC 三个数据（引导去 Semrush / Ahrefs / Google Ads 查）
- 或主动提议：用户可以导出相关 CSV，agent 用 `kdroi.py` 打分
- 只有拿到数据才继续决策

**Should NOT**:
- 附和用户的直觉说"对对对这个方向很热"
- 不查数据就给出"值得做"的结论
- 直接让用户建站

---

## Case 5 — 反例触发：已选好方向要写内容

**User input**:
> 我决定做 AI Headshot Generator 这个站了，帮我写一篇 SEO 文章推广它。

**Expected**:
- agent **不应**触发 niche-finder（方向已定，现在要写内容）
- 改为引导用户去 SEO content skill（如 `seo` 或 `frontend-design` 的 landing page 方向）
- 如果坚持用本 skill，也只应在用户明确表示"再确认一次这个方向对不对"时简短复验

**Should NOT**:
- 强行走一遍完整的 niche 挖掘流程
- 重新让用户提供 Volume / CPC / KD

---

## Case 6 — 反例触发：纯产品点子脑暴

**User input**:
> 帮我脑暴 10 个 AI 创业点子。

**Expected**:
- agent **不应**触发 niche-finder（用户要的是发散脑暴，不是数据驱动的需求挖掘）
- 改为触发 `superpowers:brainstorming`

**Should NOT**:
- 用 KDRoi 公式给脑暴点子打分（脑暴阶段还没有 SEO 数据）

---

## Case 7 — 主流程成功：端到端闭环

**User input**:
> 词根 Generator，Semrush 导出在 ~/Downloads/generator-keywords.csv 了，帮我从 0 到 1 跑一遍流程，选出最值得做的那个。

**Expected**（端到端）：
1. 确认文件存在，提示 CSV 列字段
2. 跑 `kdroi.py` 拿 Top 20
3. 挑前 3-5 个候选逐个走四步验证
   - Semrush 数据（基于 CSV 已有字段）
   - 引导用户查 Google Trends（或声明这一步需要用户反馈）
   - 引导用户查 Google SERP
   - 查 CPC 变现档位
4. 输出 Output Contract 的三块：
   - 候选清单表
   - 推荐优先做（最佳候选的详细分析）
   - 下一步动作清单
5. 最后给出四大坑的 Red Flag 自检

**Should NOT**:
- 只跑脚本不走验证
- 跑完脚本就说"选第一个"
- 跳过 Red Flag 自检

---

## 判定通过的核心标准

一个 skill 调用如果**全部满足**以下条件，就算通过：

1. 每个决策都带 KDRoi 数值
2. 提到的决策都引用了四步验证的结果
3. 候选的推荐顺序 = KDRoi 降序（不是拍脑袋）
4. 遇到缺数据场景会拒绝下结论，要求用户补数据
5. 反例场景能正确 handoff 到其他 skill（不抢工作）
6. 涉及 CSV 时调用 `kdroi.py` 而不是自己写脚本

任一不满足 → 记录为 regression，回到 skill 正文改。
