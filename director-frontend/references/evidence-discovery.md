# Evidence Discovery — director-* 通用证据查找规范

> 借鉴 ACBDQC Blueprint 强制佐证 + director-ops 的 knowledge-and-citation 实践。
> 本文件定义所有 director-* 在 audit / implement 时**证据从哪查、按什么优先级、什么算适用**。
>
> 适用范围:所有 director-* skill 的 audit / extract / implement / dispatch / install / uninstall 等 mode。

## 1. 通用原则

**没有可核对的佐证 → 不下结论**。每个评分项、每个 finding、每个 verdict 都必须能被人工 review 到原文 / 截图 / command 输出。

适用边界:
- 评分时 → 标准佐证字段格式(见 `_shared/director-template.md` 第 5 段)
- finding 时 → 含定位信息(文件:行号 / 截图:坐标 / command:行号)
- 跳过维度 → 必须 `[n/a]` + 跳过原因(不能省略)

## 2. 证据来源优先级(通用 5 层)

按以下优先级查证据,**禁止跳层**:

1. **本任务上下文**(用户原话 + 已有材料 + handoff 字段) → 最优,无歧义
2. **本项目内现成证据**(代码 / 文档 / 截图 / 已有实现)
3. **项目知识库**(`~/Documents/knowledge/<topic>-*.md`)— 沉淀的过往经验
4. **本仓库 references/**(角色特有 reference 文件 + 共享 reference)
5. **外部参考**(antd / shadcn / 设计原则 / 平台官方文档)— 最后兜底

跳层信号 = AI slop。例:不查项目内 `Button` 就照搬 shadcn `Button`(跳过第 2 层)。

## 3. 各角色证据探测命令

### director-design(视觉证据)

```bash
# 截图来源(按优先级)
ls -la <project>/.agent/screenshots/ 2>/dev/null
ls -la <project>/screenshots/ 2>/dev/null
ls -la <project>/docs/images/ 2>/dev/null

# Playwright 自截(若无现成截图)
# 视口规范:必须 1440×900 / 1024×768 / 768×1024 / 375×812 全套

# 项目 design tokens 探测
find <project> -name "tailwind.config.*" -o -name "theme.*" -o -name "tokens.*" 2>/dev/null
ls <project>/.storybook/ 2>/dev/null
```

### director-frontend(代码证据)

```bash
# 项目内相似实现查找(implement 前置必跑)
rg -l "export.*<ComponentName>" <project>/src/ <project>/app/ <project>/components/ 2>/dev/null

# 项目规范探测
ls <project>/components/ui/ <project>/features/ 2>/dev/null
rg -l "cn\(|cva\(|tv\(|clsx\(" <project>/src/ 2>/dev/null | head -3

# 状态管理探测
rg -l "createContext|useReducer|zustand|jotai|valtio|redux" <project>/src/ 2>/dev/null | head -3
```

### director-promote(平台 + 素材证据)

```bash
# 项目 hero 图查找
find <project> -path '*node_modules*' -prune -o \
  \( -name "hero*.png" -o -name "hero*.jpg" -o -name "hero*.webp" \) -print 2>/dev/null

# 平台登录态检查(playwriter 中)
# document.querySelector('#current-user')                    # Appinn
# document.querySelector('[data-testid="user-avatar"]')      # PH
# document.querySelector('.user-info') / 看右上角             # sspai

# 外链 200 校验
curl -sI -L "<URL>" -o /dev/null -w "%{http_code}\n" --max-time 10
```

### director-ops(系统 + 知识库证据)

```bash
# 知识库查找(详见 director-ops/references/knowledge-and-citation.md)
rg -n "安装|install|setup" ~/Documents/knowledge -g '*.md'
rg -n "卸载|uninstall|remove|删除|清理" ~/Documents/knowledge -g '*.md'

# 系统环境
uname -s -m
sw_vers 2>/dev/null              # macOS
cat /etc/os-release 2>/dev/null  # Linux

# 包管理器
command -v brew apt dnf pip pipx npm cargo mas 2>/dev/null
```

## 4. 证据"适用性"判断

并非找到证据就能直接用。每条证据必须过适用性闸门:

| 角色 | 适用性维度 |
|---|---|
| director-design | 截图视口尺寸 / 设备类型 / 是否为最新版 UI |
| director-frontend | 项目相似实现的样式工具 / 状态管理范式 / TypeScript 版本 |
| director-promote | 平台规则更新时间 / 调性是否仍适用 / 链接是否仍 200 |
| director-ops | 系统平台 / 安装方式 / 版本范围 / 路径(详见 director-ops/references/knowledge-and-citation.md) |

不通过适用性闸门 → 不能据此下结论,要降级:**输出候选 + 验证方法**而非"已确认"。

## 5. 佐证格式速查

| 元素类型 | 写法 | 反例 |
|---|---|---|
| 文件位置 | `[src/components/Button.tsx:42]` | "<某文件>" |
| 截图位置 | `[hero.png:中央偏左,1440×900 视口]` | "<截图>" |
| 命令输出 | `[brew list --formula → output 含 'node@20']` | "<command 结果>" |
| 平台原文 | `[v2ex/topic/123456 第 3 楼回复: "..."]` | "<用户反馈>" |
| 外部参考 | `[antd Button.md "受控 props 命名"段]` | "<参考 antd>" |
| 项目知识库 | `[~/Documents/knowledge/node-install.md 第 2 段]` | "<本地经验>" |

## 6. AI slop 反检测清单

以下信号 = 证据不足/AI 自由发挥,**自动降级**为 finding `[must-fix]`:

- 评分项写 "<证据>" / "<结论>" / "看起来不错" 等空泛词
- finding 没有定位信息(无文件 / 行号 / 坐标 / 命令输出)
- 跳过维度但**没标 `[n/a]`** 也没说理由
- 引用外部参考但**没说项目内为何不能用**(违反优先级第 2 层 < 第 5 层)
- 引用本地知识库但**没核对适用性**(平台 / 版本 / 路径)
- "通常""一般""大部分情况" 等无条件断言

## 7. 当证据不足时的标准动作

不要编造,按下面降级:

1. **明示 evidence: missing** / `evidence: code-only` / `evidence: low-confidence`
2. **不下断言性结论**(不说 "已经够好" / "可以发布")
3. **输出"为了下结论还需要什么证据"**(让用户决定补还是接受现状)
4. **若该证据无法获得**(如平台无登录无法验证)→ 降级为 `partial / unverified`,在 Output Contract 明示

## 8. 与 Output Contract 的对接

每个 director-* 的 Output Contract 必须有"证据采集"段:

```md
### 证据采集
- 探测方式: <list 用了哪些命令 / 查了哪些文件>
- 命中: <list 找到的证据>
- 缺失: <list 没找到的证据 + 影响>
- 适用性判断: <list 跨平台 / 跨版本的适用性结论>
- 降级: <若有,明示降级原因>
```
