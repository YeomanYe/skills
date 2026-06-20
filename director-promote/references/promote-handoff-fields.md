## director-promote 专属接收字段

上游 orchestrator 调 `director-promote` 时**必须传**：

| 字段 | 必填 | 说明 |
|---|---|---|
| `task_id` | ✅ | 任务唯一标识 |
| `objective` | ✅ | 一句话宣传目标（如"上线发新版 v2.0"）|
| `project_root` | ✅ | 项目绝对路径 |
| `target_platforms` | 推荐 | 默认平台清单（twitter / v2ex / appinn / sspai / chrome-store-assets）|
| `hero_image_paths` | 推荐 | 已有 hero 图路径数组 |
| `risk_class` | 推荐 | low / medium / high（high = 品牌发布/付费产品，必须 variants 后用户签字）|

如果上游已传：本 skill 不重复探测，直接用 handoff 字段。
如果上游未传：本 skill 自己探测（Step 1 收集材料 + Step 3 探测项目/平台前提）。
**禁止冗余追问**已在 handoff 给出的字段。
