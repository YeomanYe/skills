# 板块详解与决策

## 板块全景（截至本 skill 创建时，2026-05）

通过 `GET /categories.json` 拉取的可发帖板块，**只有 faxian 和 alpha 适合发新项目分享贴**。其余板块用途如下：

| id | slug | 名称 | 适合项目分享吗 | 原因 |
|---|---|---|---|---|
| 10 | faxian | 发现频道 | ✅ 主推荐 | 论坛主推荐入口（5000+ 帖），人工审核但权威 |
| 82 | alpha | alpha | ✅ 备选 | 描述写明"早期产品 / 随手分享"，立即可见 |
| 7 | wen-ti-qiu-zhu | 问题求助 | ❌ | 是问问题的板块 |
| 6 | discuss-and-share | 讨论分享 | ⚠️ 不推荐 | 范围太宽，发新项目会被埋 |
| 5 | guan-shui-liao-tian | 闲聊灌水 | ❌ | 闲聊性质，不适合项目 |
| 59 | collections | 软件集合 | ❌ | 同类软件汇总，不适合单项目 |
| 26 | favorite-apps | 我最喜爱 | ❌ | 用户投票分类，非作者发 |
| 其他 | — | 站务/插件/Discourse 等 | ❌ | 论坛运营类 |

## faxian vs alpha 决策树

```
项目是否已上架到任意正式渠道（Chrome Web Store / App Store / 官网正式发布 / PyPI / npm）？
  ├─ 是 → 是否有真实可演示的核心功能（不是 placeholder）？
  │       ├─ 是 → faxian（默认）
  │       └─ 否 → alpha
  └─ 否 → 是否纯本地脚本 / 周末实验？
          ├─ 是 → alpha
          └─ 否（已部署 demo / 公开仓库 + README） → 用户选；倾向 alpha
```

## 两个板块的代价对比

### faxian (id=10) 的代价
- **审核延迟**：人工审核，几小时到几天，作者侧无法主动催
- **审核被拒可能**：明显的硬广、违法/灰产内容会被拒；正常开源项目极少被拒
- **API 响应**：成功提交时返回 `{"action":"enqueued", "success":true, "pending_post":{"id":N}}`，**没有** topic_id；通过审核后才生成 topic
- **发出后无法直接编辑标题**：要 @ 版主或在帖子内追加内容
- **回报**：可能被小众软件主站（青小蛙运营）选中搬到首页文章，曝光放大

### alpha (id=82) 的代价
- **流量小**：板块本身帖子量少（约 285 帖），不在主推荐入口
- **氛围更随意**：可以"我搓的"调性，用户预期是"半成品分享"
- **API 响应**：直接返回 `{"action":"create_post", "topic_id":N, ...}`，立即可见
- **可立即编辑**：作者本人可以随时编辑标题和正文（查 `can_edit` 字段）

## 决策检查清单

在告诉用户最终板块前，问自己：

1. 产品有公开发布渠道吗？
2. 第一波用户能立刻用起来吗？
3. 文案调性匹配板块吗？（faxian 用推荐口吻，alpha 可用"我搓的"）
4. 用户能接受 faxian 的审核延迟吗？

如果答案是 (是, 是, 推荐口吻, 能接受) → faxian
如果有任一不满足 → alpha 更稳

## 拉取最新板块列表

板块 id 可能随时调整，发帖前最好拉一次最新列表确认：

```js
page.evaluate(async () => {
  const r = await fetch('/categories.json', {headers:{'Accept':'application/json'}});
  const j = await r.json();
  return j.category_list.categories.map(c => ({id: c.id, name: c.name, slug: c.slug, topic_count: c.topic_count}));
})
```
