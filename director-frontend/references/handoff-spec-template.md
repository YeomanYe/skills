# Frontend Handoff Spec 模板

`handoff` mode 的产物 = 工程可用 UI spec。写盘路径 `.agent/frontend-handoff/<task-id>/spec.md`,同时把路径回传给 orchestrator。

**spec 缺一字段就会被下游反复来回追问** —— thinking guide:模拟后端 / plugin 工程师只读这份 spec 不看代码,问"能否照着独立实现且与本仓库现有 UI 风格无缝衔接"。

```md
# Frontend Handoff: <task-id>

## 组件目标
<组件名 + 一句话用途>

## 组件层级
<primitive / shared / business / page-local>

## 文件位置
<absolute path>

## props API
- <name>: <type> — <说明>

## 状态边界
- 受控/非受控:
- 内部状态: <list>

## 样式约定
- 用 <Tailwind/CSS Modules/cva>
- variant 设计: <description>

## 依赖
- 项目内: <list>
- 外部: <list,需明示理由>

## 交互状态
- normal / hover / focus / disabled / loading / empty / error 各自处理

## 验收点
- 必须保留的交互:
- 必须保留的视觉:
- 必须不破坏的导入路径:

## 不要做什么
- ...
```

**handoff 出口**(不调用,只交付):
- `frontend-design` plugin — 实际写代码(若本 skill 选择不自写,handoff 给它)
- `delivery-gate` — 交付前总审查
- `director-design` — 视觉复审
