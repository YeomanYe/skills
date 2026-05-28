# Failure Modes — Red Flags / Rationalizations / Common Mistakes

> 主体 SKILL.md 用 1 行引用本文件；具体反模式 + 自欺台词 + 易翻车清单全在这里。

## Red Flags —— STOP 并重新考虑

- Stage 1 没出 ASCII 流程图就进 Stage 2（**仅当用户要求过流程图时**）→ 停下，先补流程图
- Stage 1 preview 设计标 Required 但没写 Component reuse plan（项目有 UI 组件时） → 停下，按 project-prep 第 4 条硬要求补全
- 用户还没在 user gate 的 4 项决策里至少明确 1/2/3 三项 → 停下，触发 user gate 问完再说
- Stage 2 用户还没"挑定 1 个 mockup"就开始出 logo / preview → 停下，等用户决策
- Stage 2 部署后没回填总设计文档的 URL → 停下，回填两处
- 把私有仓库默认部署到 GitHub Pages → 停下，公开仓库泄露风险
- 把公开仓库默认走 Cloudflare（用户没要求） → 停下，过度复杂
- 整体走完没列开放决策 → 停下，补总设计文档第 8 节

### v5.1 部署凭据 Red Flags
- **token 写进 git**（commit / README / docs / wrangler.toml / package.json）→ 停下，立刻 `git reset --hard` + revoke token + 重新生成
- **token 在对话 / log / commit message 里裸传明文** → 停下，agent 必须用 `${VAR}` 引用
- **1.5.2 凭据缺失但跳过提示直接进 Stage 2.4** → 停下，回 1.5 让用户配齐
- **Stage 2.4 部署前不二次校验凭据** → 停下，环境变量可能在 Stage 1 之后被改/失效
- **`.envrc` 没写进 `.gitignore`** → 停下，会泄露到 GitHub

## Rationalizations to Reject

| 说辞 | 现实 |
|------|------|
| "ASCII 流程图用文字描述代替更省事" | 流程图的价值是"一眼看到决策点"，文字段落看不出来。该画就画 |
| "preview 设计可以挪到 Stage 2 再说" | preview 是 Stage 1 锁定项之一；Stage 2 实施它需要 Stage 1 先描述清楚 |
| "用户口头说 OK 了就直接进 Stage 2" | user gate 必须显式列出决策清单让用户回答；口头模糊的"OK"不算锁定 |
| "私有仓库也用 GitHub Pages 算了" | GitHub Pages 公开访问 = 私有项目内容暴露；闭源项目必须 Cloudflare 或其他闭源友好平台 |
| "logo 用 emoji 或纯文字省事" | logo 是品牌识别度；emoji / 纯文字是占位思路，不是 logo 设计。必须出 ≥ 2 方向 |
| "preview 页和设计文档放一起就行，不用双向链接" | 双向链接保证两份资产长期对齐：改了 preview 找得到出处，看了文档点得开 preview |
| "Stage 1 全量候选可以删掉用户没选的" | 全量候选是文档的一部分；保留未选的方便日后回看 tradeoff |
| "用户已经走过 project-prep 了，可以跳 Stage 1" | Stage 1 不只是 project-prep，还含 ASCII 流程图 / 设计方向 + mockup / 部署方案，必须完整跑 |
| "只给 1 套设计候选用户能接受就好" | ≥ 2 套候选才让用户有选择权；只给 1 套 = 用户没的选 = 改回头成本极高 |

## Common Mistakes

- 把 MVP 当成范围裁剪而不是交互承诺
- Stage 1 没出 ASCII 流程图就交付（用户明确要求过时）
- Stage 1 给了候选 mockup 但没让用户选就进 Stage 2
- Stage 2 出 logo 但只出一个方向
- Stage 2 preview 页部署后忘记回填总设计文档的 URL
- 私有仓库默认部署到 GitHub Pages 暴露内容
- 把下游 skill 的内容用自己的 voice 改述
- 跳过 preview decision 直接开始 → preview 是 Stage 1 必问的 4 件之一
- 越界做 PM 工作 / 写实际代码 / 出生产设计 → 编排器不是 PM 替身
