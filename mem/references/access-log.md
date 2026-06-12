# access-log.jsonl 格式 spec

`data/access-log.jsonl` 是 JSON Lines 文件——每行一个 JSON 对象。
用途:升格阈值统计(hit_count) + TTL 淘汰(last_access) + 调试 / 审计。

## 写入规则

**每次 lookup(无论命中)**:append 一行 `op: "read"`
**每次 write / promote / archive**:append 一行 `op: "write"` / `"promote"` / `"archive"`

## 单行 schema

```json
{
  "ts": "2026-06-12T15:00:00.000Z",
  "op": "read | write | promote | archive",
  "category": "env | unblock | staging",
  "slug": "<entry slug or null>",
  "query": "<lookup query keywords joined by space, or null>",
  "hit": true,
  "hit_count_after": 5,
  "actor": "claude-code | codex | other-agent-id",
  "session_id": "<optional, for traceability>"
}
```

字段说明:

| 字段 | 必填 | 含义 |
|---|---|---|
| `ts` | ✅ | ISO 8601 时间戳(UTC) |
| `op` | ✅ | 操作类型 |
| `category` | ✅ | 操作的分类 |
| `slug` | 仅 op=read/write 命中具体 entry 时填 | entry slug,跟文件名一致 |
| `query` | 仅 op=read | lookup 用的关键词,空格连接 |
| `hit` | 仅 op=read | 是否命中(为 INDEX 索引质量做 baseline) |
| `hit_count_after` | 仅 op=read/write 命中 entry 时填 | bump 后的 hit_count |
| `actor` | ✅ | 哪个 agent 跑的 |
| `session_id` | 可选 | 会话标识(用户/orchestrator 追溯) |

## 例子

### 命中 lookup
```json
{"ts":"2026-06-12T15:00:00.000Z","op":"read","category":"unblock","slug":"lark-wiki-docs-use-lark-cli","query":"Lark wiki WebFetch 拿不到","hit":true,"hit_count_after":6,"actor":"claude-code"}
```

### 未命中 lookup
```json
{"ts":"2026-06-12T15:05:00.000Z","op":"read","category":"unblock","slug":null,"query":"Slack OAuth 403","hit":false,"actor":"claude-code"}
```

### 新 entry 写入
```json
{"ts":"2026-06-12T15:10:00.000Z","op":"write","category":"staging","slug":"slack-oauth-403-need-redirect","actor":"claude-code","session_id":"abc"}
```

### 升格(staging → unblock)
```json
{"ts":"2026-06-15T10:00:00.000Z","op":"promote","category":"staging","slug":"slack-oauth-403-need-redirect","actor":"claude-code"}
```

## 注意事项

1. **append-only**:不要 rewrite 历史行(rewrite 会丢统计)
2. **只写中心仓库**:`~/Documents/projects/skills/mem/data/access-log.jsonl` 是单一事实源,下游副本不写
3. **不进 git LFS**:size 增长慢(每次 lookup ~200 bytes),纯文本就够;**但确实要进 git**,因为 hit_count 升格阈值跨设备共享要靠它
4. **PII 自查**:`query` 字段不要写真实邮箱 / 用户姓名 / 内部域名

## 读取(谁会读 access-log)

| 读者 | 用途 |
|---|---|
| `mem` 自身的 promote 流程 | 算 staging entry 是否到 `hit_count ≥ 3` 升格阈值 / 90 天 TTL |
| `mem` lookup 命中后 bump | 找到 entry 当前的 hit_count(也可从 entry frontmatter 读,access-log 是冗余源) |
| 用户/审计 | "我上次 lookup 这条是什么时候" / "哪些 entry 最常被 hit" |

不需要 agent 在常规 lookup 中读 access-log——只在 promote 报告时按需扫描。
