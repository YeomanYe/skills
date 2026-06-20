# director-architect — 并行化方案

> 通用并行编排规范见 `references/parallelization-template.md`（共享）。
> 本文件记录 director-architect 的具体并行 slot 表、Reduce 策略和预期收益。

## Slot 表

| Slot | 任务 | 形态 | 串/并 |
|---|---|---|---|
| `stack-detect` | Step 2 读元信息（package.json / Cargo.toml / go.mod 等） | Bash 并行 | 并 |
| `skill-scan` | Step 3 扫 4-5 个本地 skill 目录 | Bash 并行 | 并 |
| `rules-read` | Step 1 读本项目规范 + 可选参考项目规范 | Bash 并行（cat / find 同时跑） | 并 |
| Step 4 联合评估 | 串行（依赖前 3 路全部完成） | — | 串 |
| Step 6 结构设计 | 串行（依赖 Step 4 + 5 输出） | — | 串 |
| Step 7-9 落地 | 串行（顺序写文件） | — | 串 |

## Reduce 策略

方式 3（内存 JSON 汇总）—— 3 路 Bash 输出由本 skill 解析合并成单一 `evaluation-input.json`，交给 Step 4。

orchestrator 在 3 路 Bash 派发后短暂 idle（等待最长一路完成，通常是 clone 参考项目）。纯 Bash 并行不需要派 subagent。

## 收益与超时

- 原 ~10min 串行（含 clone 参考项目）→ ~5min
- 参考项目 clone 慢（网络）会拖累，可设 30s 超时；超时则降级为"只评估本项目"分支
