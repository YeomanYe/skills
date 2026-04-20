# Quote 引用卡片模板

适合引用式、大字号、单段正文高亮类卡片，也适合延展为标题型封面图。典型场景：小红书金句卡、观点卡、社区宣传卡。

模板文件：`quote-text-card-template.html`

## 卡片尺寸

- 宽高：1080 × 1440 px
- 宽高比：3:4

## 渲染参数

```bash
--viewport-width 1080 --viewport-height 1440
```

## 变量说明

### 颜色变量（CSS `:root`）

| 变量 | 说明 | 示例值（purple） |
|------|------|------------------|
| `--bg` | 卡片背景色 | `#ede7fb` |
| `--text` | 正文文字颜色 | `#403d52` |
| `--quote` | 左上角引号颜色 | `#dfcef0` |
| `--accent` | 高亮下划线颜色 | `#f7be3f` |
| `--dash` | 右下角短横线颜色 | `#dfcef0` |

### 内容变量（HTML）

模板中正文区域的结构为：

```html
<div class="content-text">
  {{content_prefix}}<span class="highlight">{{highlight_text}}</span>{{content_suffix}}
</div>
```

| 变量 | 说明 |
|------|------|
| `{{content_prefix}}` | 高亮词之前的文案 |
| `{{highlight_text}}` | 高亮关键词（底部会渲染彩色下划线） |
| `{{content_suffix}}` | 高亮词之后的文案 |

实际使用时不一定严格按三段式，可以自由组合多个 `<span class="highlight">` 和普通文本。参考示例中的写法：

```html
加入<span class="highlight">方圆AI社区</span>，了解 AI 工具、<span class="highlight">通俗易懂</span>的方法和实践内容
```

## 文案约束

| 约束项 | 限制 | 原因 |
|--------|------|------|
| 正文总字数 | **建议 ≤ 30 字** | 字号 104px，容器宽度 878px，文案过长会导致内容溢出可视区域 |
| 单个 highlight 关键词 | **建议 ≤ 6 字** | highlight 使用 `white-space: nowrap` 不会自动换行，过长会超出容器宽度 |
| highlight 数量 | 建议 1–2 个 | 太多高亮会分散视觉焦点 |

## 示例样式

### purple（淡紫）

文件：`example-quote-text-card-purple.html`

```
--bg: #ede7fb        淡紫背景
--text: #403d52      深灰紫文字
--quote: #dfcef0     浅紫引号
--accent: #f7be3f    金黄高亮下划线
--dash: #dfcef0      浅紫短横线
```

### blue（浅蓝）

文件：`example-quote-text-card-blue.html`

```
--bg: #cef0ff        浅蓝背景
--text: #2f3a4a      深灰蓝文字
--quote: #a3d5f2     蓝灰引号
--accent: #fdb8f6    粉紫高亮下划线
--dash: #a3d5f2      蓝灰短横线
```

## 配色技巧

- `--bg` 和 `--quote`/`--dash` 同色系但有深浅差异，保持视觉统一。
- `--accent` 通常选择与背景色对比鲜明的暖色（金黄、粉色等），用于吸引视线。
- `--text` 需要与 `--bg` 有足够对比度以保证可读性。
