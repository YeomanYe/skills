# Example · Ext Helper Chrome Web Store Small Promo (440×280)

## Context

- Project: a browser extension manager（Plasmo / Chrome / Firefox / Edge）
- Slot: Chrome Web Store **small promotional tile**, 固定 440×280
- Brand language already defined: dark navy bg + cyan primary + magenta secondary, "punk" 主题
- 用户原始要求：图标放左、双行文案在右、有间距、右下角加一个**符合主题的 switch 符号**

## Key Decisions

1. **图标左 + 文案右** 的横向布局优于上下堆叠 —— 440×280 偏宽，竖向布局会浪费横向空间。
2. **双行文案是允许的**，因为：
   - 主视觉由图标承担，文字不需要再扛
   - 用强动词节奏 `Group · Automate · Bisect` 替代长句，密度高但仍可一眼读完
   - 这是对 SKILL.md "小图优先单主视觉 + 极短文案" 的一个**有边界条件的破例**，不是反例
3. **右下角的 toggle 开关**呼应产品语义（扩展开关），不是装饰 —— 这是"产品语义微符号"的好例子：在角落放一个能让用户秒懂产品做什么的小图形。
4. **去掉了图标四角的角标装饰**：因为它和图标本身的方框轮廓互相竞争。装饰一旦和主体语言冲突，删除优于微调。
5. **画布无圆角**：Chrome Web Store 小宣传图槽位本身会被裁切到方形显示，自带圆角反而会在不同主题/位置出现"圆角嵌圆角"。统一直角输出，由商店控制视觉边缘。
6. **导出链路**：HTML → `agent-browser --allow-file-access` → `set viewport 440 280 1`（**1x 原生尺寸**）→ `screenshot`，得到准确像素的成品位图。**不要用 2x retina**——商店明确要求 440×280 像素，retina 出来的 880×560 不符合规格。

## Reusability

可以复用的部分：
- 整体布局骨架（icon left / two-row copy / corner motif）
- 色板与字体组合（JetBrains Mono + Space Grotesk + cyan/magenta on dark navy）
- 截图工作流

需要按项目改的：
- 图标内容、品牌色、字体（按目标项目的 brand-spec）
- 右下角的"产品语义符号"——必须根据该产品的核心动作重选（搜索工具放放大镜、笔记工具放钢笔、定时工具放沙漏…）
- 文案中的强动词节奏

## Files

- `promo.html` — 完整可复用源码
- `output.png` — 成品位图（**440×280 原生尺寸，1x，无圆角**）
