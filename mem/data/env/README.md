# data/env/ — 环境事实清单(metadata only)

本目录装**变量清单 / 本机/项目环境事实的 metadata**。

**变量值不在这里**——值统一存放在:

```
~/Documents/knowledge/local/.env    # 权限 600,不进任何 git
```

本目录每个 `<slug>.md` 只记录:**叫什么名字 / 用途 / 读法 / 缺失时怎么办**。

详细 schema 见 `mem/references/categories/env.md`。

---

## 当前 entry

(尚未登记任何 entry。原 env-registry 的"变量清单"部分尚未填条目就并入 mem,后续按需从实际使用中补登记。)

---

## 添加新 entry 的最小流程

1. 读 `mem/references/categories/env.md` schema
2. 在本目录创建 `<slug>.md`(scope 选 `vars-registry` / `local-host-<hostname>` / `project-<project-slug>`)
3. 更新 `mem/INDEX.md` 的 env 分类段(对应 tag 下加 slug + symptom 反查表加 1-N 行)
4. append `mem/data/access-log.jsonl` op=write

**绝对不要**:
- 把明文 value 写进任何 `<slug>.md`(只记引用)
- 把 `~/Documents/knowledge/local/.env` 加进 git
- `cat ~/Documents/knowledge/local/.env` 输出到日志 / 对话
