# Output Contract — 总设计文档模板 + 两阶段最终交付清单

> 主体 SKILL.md 用 5-15 行引用本文件；模板全文 + 最终交付清单都在这里。

## Stage 1 总设计文档模板

Stage 1 末尾交付**单一文档**（建议路径：`docs/design.md` 或 `DESIGN.md`），按以下顺序：

```md
# {项目名} · 总设计文档

## 1. MVP & 用户
（in scope / out of scope / non-goals / 目标用户 / 核心流）

## 2. 主流程图
（ASCII 流程图）

## 3. 主交互设计
（屏幕清单 / 关键动作 / 状态流转 / 决策点）

## 4. 主要技术栈
（运行面 / 框架 / 主语言）

## 5. 设计方向 + Preview Mockup（**v5 合并原 5 + 6**）
- Status: Required / Not needed / Already satisfied
- **3 路 mockup 路径**:
  - `.agent/jobs/preview-mockup-1/` — style: <name>
  - `.agent/jobs/preview-mockup-2/` — style: <name>
  - `.agent/jobs/preview-mockup-3/` — style: <name>
- **方向卡**: `.agent/jobs/director-design-variants/directions.md`
- **飞书推送**: pushed (6 截图) | skipped (non-feishu)
- **用户选定**: mockup-N (style: <name>) | pending | "都不行 重做"
- **Component reuse plan**（被挑 mockup 的 meta.json 中提取）:
- 预览页地址（占位）: `<PREVIEW_URL>`（Stage 2.3 完成后回填）

## 6. 部署方案（原 7 节）
- Repo visibility: public / private
- 部署目标: GitHub Pages / Cloudflare Pages / Vercel / Netlify / 自托管 / 不部署
- 偏离默认的理由（如有）:
- **凭据就绪状态**（v5.1）:
  - 所需环境变量: `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID`（按目标改）
  - 检测时间: <ISO ts>
  - 状态: ✅ ready | ⏳ 等用户配置 | n/a (GitHub Pages / 不部署)
  - 存储方式: shell rc | direnv .envrc | keychain
  - **不记录 token 值本身**（敏感信息禁入文档）

## 7. 后续规划（post-MVP roadmap，原 8 节）
（暂缓事项 / 扩展点 / 规模预期；无则明写"本期未讨论"）

## 8. Stage 1 待用户锁定的决策（原 9 节）
- [ ] 接受 MVP 切片
- [ ] **挑选 1 个 preview mockup**（mockup-1 / 2 / 3 / 都不行重做）
- [ ] 确认部署方案
- [ ] 确认后续规划方向
```

## 两阶段最终交付清单

### Stage 1 产物
1. **总设计文档**（单一文件），覆盖 8 个章节（MVP、流程图、交互、技术栈、preview 设计 + 设计方向、部署方案、后续规划、待锁定决策）
2. ASCII 流程图（嵌在总设计文档第 2 节）
3. ≥ 2 套设计方向卡 + 3 路 preview mockup（路径嵌在第 5 节，全量保留）

### Stage 2 产物
4. 工程规范脚手架（或 patch）
5. 项目 logo（≥ 2 个方向；用户选定后归档到 `assets/logos/`）
6. **可访问的 preview 页**（如 Stage 1 判 `Required`），并已部署到目标平台
7. **双向链接已建立**（preview 页 ↔ 总设计文档，URL 已回填）

任一缺失视为未完成。

## Delivery Check

宣称 bootstrap 完成前，核对：

### Stage 1
- 总设计文档已落盘（路径：`docs/design.md` 或等价）
- 8 节齐全（MVP / 流程图 / 交互 / 技术栈 / 设计方向+preview / 部署方案 / 后续规划 / 待锁定决策）
- ASCII 流程图存在（若用户要求）
- preview 设计满足 project-prep 的 4 条硬性要求（含 Component reuse plan，若项目有 UI 组件）
- 3 路 mockup 全量保留（用户可对比）
- 部署目标根据仓库可见性正确路由（public → GitHub Pages / private → Cloudflare）
- "后续规划"段落存在或显式写"本期未讨论"
- 触发了 user gate 询问 4 项决策

### Stage 2
- 工程规范脚手架已落盘
- 项目 logo ≥ 2 方向，文件已归档
- preview 页（如 Required）已实现并部署
- **双向链接已建立**：preview 页有"返回总设计文档"链接 + 总设计文档"预览页地址"已回填真实 URL
- 部署 workflow / 配置文件已落地
