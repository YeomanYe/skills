# Promote Parallelization — 派工模板详细规范

本文件补充 `parallelization-template.md` 的通用规范，记录 `director-promote` 专属的并行派工模板。

---

## variants 模式：派工 prompt 模板（每路 subagent）

```
Slot: variant-N
Task: 为 <project> 出第 N 个宣传文案调性版本

必须遵循 director-promote 的 9 维 audit checklist 作为评分基线。
目标平台: <platform>
调性约束: <variant-N 的具体风格>

输入(只读):
  - 项目 README / package.json
  - 已有 hero 图路径
  - 目标平台调性(参考 references/platforms/<platform>.md)

输出目录: .agent/jobs/promote-variant-N/(禁动其他 variant-* 目录)
返回 JSON: {slot, status, output_dir, tone_name, title, body_md, hashtags, hero_path, tradeoffs, errors}

约束:
  - 必须与其他 variants 真正差异化(标题/开头/结构/语气至少 2 个维度不同,不能只换 emoji 或 hashtag)
  - 严守目标平台的字符/格式限制
  - 不得生成超出 references/promote-principles.md 9 维边界的"创意"
```

orchestrator 派 N 路 subagent 后**进入 idle**，各路返回触发唤醒后汇总成 variants 报告。
单路失败不阻塞其他（collect-all）。

---

## 调用 director-design subagent 的派工模板（按平台分化）

当 draft / audit 阶段需要 hero 图 / 商店素材时，派 subagent 调 `director-design`。
**subagent 默认不会主动 invoke skill，必须在 prompt 里显式指挥**；且**每个目标平台的
尺寸 / 格式 / 内容约束不同，必须按平台注入对应 spec**。

### 第一步：按目标平台选 spec

| 目标平台 | spec 来源 | 关键约束摘要 |
|---|---|---|
| Chrome Web Store | `references/chrome-store-assets.md` | 1-5 张截图、**≥1 张必须 1280×800**、促销图**必含截图**、5 张**必须差异化** |
| Edge Add-ons | `references/platforms/edge.md` | **300×300 logo tile（用项目图标设计）**、截图 1366×768 或 1920×1080、同上差异化 |
| 社区平台（twitter / v2ex / appinn / sspai / producthunt） | 对应 `references/platforms/<name>.md` | hero 图，各平台比例不同（twitter 16:9 / sspai 1600×1200 ...） |

### 通用派工 prompt 模板（`<...>` 处按平台 spec 填充）

```
Task: 为 <project> 生成 <平台名> 的 <hero 图 | 商店素材包>

必须调用的 skill:
  - **director-design**(mode=mockup)
    subagent 默认不会主动 use skill，本指令明确要求你 invoke director-design

目标平台: <chrome-web-store | edge-addons | twitter | v2ex | ...>
平台 spec(只读，严格遵守): <对应 references 文件路径>

输入(只读):
  - 产品类型: <product_type>(extension popup / SaaS dashboard / landing page / mobile app)
  - 项目图标源: <icon 文件路径>(Edge logo tile / 商店 icon-128 必须基于此)
  - 已有 evidence / 真实截图: <evidence_paths>
  - 项目设计 tokens: <design_tokens_source 路径，若无 → 用默认>

需产出的素材清单(按平台 spec):
  - <例:chrome → promo-tile-440x280 + 5 张差异化截图(≥1 张 1280×800);
         edge   → logo-tile-300x300(基于项目图标)+ 截图;
         twitter→ 1 张 16:9 hero>

输出目录: .agent/jobs/promote-asset-<平台>-<task-id>/(禁动其他平台目录)
返回 JSON: {status, platform, asset_paths[], dimensions[], differentiation_note, style_decisions, errors}

硬约束:
  - 必须由 director-design 完成，不要 subagent 自己瞎画
  - 严守该平台 spec 的尺寸 / 格式 / 数量规范
  - **同平台多图必须差异化**：多张截图/宣传图在「展示功能 / 使用场景 / 取景视角」
    至少 2 个维度不同，禁止只换配色或换 demo 数据（详见 chrome-store-assets.md
    差异化段）。返回 JSON 的 differentiation_note 必须逐张说明差异点
  - **单张合成图内不重复截图**：一张 promo tile 若嵌多个截图，这些截图必须各不相同
  - **Edge logo tile 只能用项目图标**：300×300 logo tile 禁止放产品截图
  - **合成宣传图排版均衡**：promo tile / logo tile / 海报类的元素在画布上均衡分布、
    视觉重心居中，不堆一角、不留大片空白（产品真实截图不受此约束）
  - **原始素材无失真**：截图/图标接入时只能等比缩放 + 构图性裁切，禁止非等比拉伸变形、
    禁止裁掉产品关键内容（比例对不上 → 重新出图或加留白衬底，不靠拉伸硬塞）
  - 不得输出含敏感信息（IP/邮箱/钱包/密码）的截图
```

### 多平台并行派工（每平台一路 subagent）

一次任务要同时出 Chrome + Edge 素材时，**按平台拆成多路并行 subagent**，每路只负责
一个平台、用一套平台 spec、写独立目录：

| Slot | 平台 | spec | 输出目录 |
|---|---|---|---|
| `asset-chrome` | Chrome Web Store | `chrome-store-assets.md` | `.agent/jobs/promote-asset-chrome-<id>/` |
| `asset-edge` | Edge Add-ons | `platforms/edge.md` | `.agent/jobs/promote-asset-edge-<id>/` |
| `asset-<community>` | twitter / v2ex / ... | `platforms/<name>.md` | `.agent/jobs/promote-asset-<name>-<id>/` |

orchestrator 派多路 subagent 后**进入 idle**，collect-all 收齐后把各平台 asset_paths
塞回 draft 产物 / store-assets 交付目录。单路失败不阻塞其他平台。

**禁止**：用同一套约束给所有平台出图（尺寸会错）、或一路 subagent 同时出多平台素材
（平台 spec 混用，产出不可用）。
