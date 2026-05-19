# Platform: Microsoft Edge Add-ons — 商店素材规范

> 由 `director-promote` 的 `draft` 模式生成,**交付**给 `flow-ext-publish` 执行上架。
> 本 skill **不执行**上架动作,只产素材。

## 与其他 platforms/*.md 的区别

`platforms/twitter.md` / `v2ex.md` 等是 **dispatch 模式的发帖自动化子模块**(用 playwriter
操控浏览器发帖)。本文件不同:**Edge 是商店素材 spec**,跟 `chrome-store-assets.md` 同类——
描述 Edge Add-ons 上架需要哪些素材、各自尺寸格式,供 `draft` 模式按 spec 派 `director-design` 出图。

Edge 商店**没有发帖自动化**,不参与 dispatch mode。

## Edge Add-ons 与 Chrome Web Store 的关键差异

| 素材 | Chrome Web Store | Edge Add-ons |
|---|---|---|
| **logo tile** | 无此项 | **300×300,必填,必须基于项目图标设计** |
| 商店图标 | 128×128 | 128×128(同 Chrome) |
| 截图 | 1280×800 或 640×400 | **1366×768 或 1920×1080** |
| 促销图 | 440×280 / 920×680 / 1400×560 | 不需要 marquee;可选 promo |
| short_description | ≤ 132 字符 | **≤ 200 字符** |
| long_description | ≤ 16000 字符 | 类似,更结构化的"扩展功能说明" |

**不要把 Chrome 的 1280×800 截图直接拿来当 Edge 截图** —— 尺寸不符,Edge 商店会要求重传。

## 必填素材

| 素材 | 尺寸 | 格式 | 备注 |
|---|---|---|---|
| **logo tile** | **300×300** | PNG | **Edge 商店列表 / 详情页用,必须基于项目图标设计** |
| 商店图标 | 128×128 | PNG | 商店元数据图标 |
| 截图 | 1366×768 或 1920×1080 | PNG / JPG | 1-5 张,多张之间必须差异化 |
| short_description | ≤ 200 字符 | 纯文本 | 商店卡片副标题 |
| long_description | — | Markdown 子集 | 商店详情页正文 / 扩展功能说明 |

## 素材生成原则

### logo tile(300×300,Edge 特有)

调 `director-design mode=mockup` 生成。要求:
- **只能用项目图标(图形标识),禁止放产品截图** —— logo tile 是品牌图标位,不是截图位。
  里面不能出现扩展界面截图 / 浏览器画面 / 任何产品 UI 抓图;只能是项目图标的图形元素
- **必须基于项目已有的图标设计** —— 不是凭空画新图,也**不是**把 128×128 的 icon 简单缩放。
  300×300 是更大画布,要重新构图
- **排版均衡分布**:图标主体在 300×300 画布上**视觉重心居中、均衡分布**,
  四周留白对称,**不堆一角、不留大片空白**。可加品牌色背景,但主体不能偏置
- **派工时必须把项目图标源文件路径作为输入传给 director-design**
- 视觉风格与项目图标一致(同一套品牌色 / 同一图形语言)
- 不堆文字:logo tile 是图形标识,产品名最多作为小字辅助,不是文字海报

> 注意区分:Chrome 的 **promo tile** 必须含产品截图,Edge 的 **logo tile** 禁止含截图。
> 两者用途不同——promo tile 是推广卡片,logo tile 是品牌图标位,不要混淆规则。

### 截图

- 1-5 张,尺寸 **1366×768 或 1920×1080**
- 真实使用截图,用测试数据(无敏感信息)
- **多张之间必须差异化** —— 差异化标准与 `chrome-store-assets.md` 的"同平台多图差异化"段
  **完全一致**:展示功能 / 使用场景 / 取景视角,至少 2 维不同,禁止只换配色或换 demo 数据

### short_description / long_description

- short ≤ 200 字符,一句话说清"解决什么问题 / 给谁用"
- long 用 Markdown,结构参考 `chrome-store-assets.md` 的 description 模板

## 派 director-design 的 spec(供 SKILL.md 派工模板填充)

派 `asset-edge` slot 的 subagent 时,prompt 的关键字段:

```
目标平台: edge-addons
平台 spec: references/platforms/edge.md

需产出的素材清单:
  - logo-tile-300x300.png  —— 必须基于项目图标源文件 <icon 路径> 重新构图
  - 截图 1-5 张,1366×768 或 1920×1080,多张差异化
  - icon-128.png

硬约束:
  - logo tile 必须 300×300,基于项目图标设计,不是缩放 128 图
  - logo tile 只能用项目图标(图形标识),**禁止放产品截图 / 扩展界面抓图**
  - 截图尺寸只能是 1366×768 或 1920×1080,不能用 Chrome 的 1280×800
  - 多图差异化:展示功能/场景/取景至少 2 维不同
  - 单张合成图内若嵌多个截图,这些截图必须各不相同(禁止同一截图摆多遍)
  - differentiation_note 逐张说明差异点
```

## 交付目录

```
.agent/promote-handoff/<task-id>/store-assets/edge/
├── logo-tile-300x300.png
├── icon-128.png
├── screenshots/
│   ├── 01-overview.png        # 1366×768 或 1920×1080
│   ├── 02-feature-A.png
│   └── ...                     # 最多 5 张,差异化
└── description.md              # short_description + long_description
```

## 交付给 flow-ext-publish

Edge 素材包是 `store-assets/edge/` 的一部分,随整个 `store-assets/` 交付给 `flow-ext-publish`
执行上架。本 skill **不**登录 Edge partner center,**不**执行上传。
