# sspai 题图制作与上传

## 尺寸与裁剪

少数派题图默认按 **4:3** 比例渲染：列表页缩略、文章顶部 hero。

| 尺寸 | 评价 |
|---|---|
| **1600 × 1200** | ⭐ 推荐：4:3 原比，画质够，加载也不重 |
| 1920 × 1440 | 也行，文件偏大 |
| 1280 × 960 | 最低可接受 |
| 1280 × 640 (2:1) | ❌ 会被裁掉上下，构图死 |
| 横长比 (>1.7:1) | ❌ 同上 |

## 构图原则

- **全画布构图**：内容铺满边到边，不要白边、不要圆角、不要外层卡片
- 因为 sspai 渲染时会再裁一次，外层圆角会被切掉，看起来像 bug
- **核心元素居中或留 60/40 分布**：列表缩略图会进一步缩到 ~400×300，远处的小元素会糊掉
- **文字尺寸**：主文字至少 80px 起；正常情况下「项目名」做最大字号，副标题做次级

## HTML → 截图工作流

如果项目里没有现成的题图，最快路径是写一份 1600×1200 的 HTML 海报，用 Playwright 截图：

```js
// _render-cover.mjs
import { chromium } from 'playwright';

const targets = process.argv.slice(2);
const browser = await chromium.launch({ channel: 'chrome' });
try {
  for (const html of targets) {
    const ctx = await browser.newContext({
      viewport: { width: 1600, height: 1200 },
      deviceScaleFactor: 1
    });
    const page = await ctx.newPage();
    await page.goto('file://' + html, { waitUntil: 'networkidle' });
    await page.waitForTimeout(800); // 等 web fonts 落定
    const out = html.replace(/\.html$/, '.png');
    await page.screenshot({
      path: out,
      omitBackground: false,
      fullPage: false,
      clip: { x: 0, y: 0, width: 1600, height: 1200 }
    });
    await ctx.close();
  }
} finally {
  await browser.close();
}
```

用 `channel: 'chrome'` 走系统 Chrome——避免下载 Playwright bundled chromium 时的网络问题。

调用：

```bash
node _render-cover.mjs ./cover.html
```

## HTML 模板原则

```html
<html>
<head><style>
  html, body { width: 1600px; height: 1200px; margin: 0; padding: 0; overflow: hidden; }
  body { background: <项目主色>; color: <项目文字色>; }
  /* 全画布，不要 max-width / margin auto */
</style></head>
<body>
  <!-- 内容直接铺到 1600×1200 -->
</body>
</html>
```

注意：

- `html, body` 写死 1600×1200，不留外边距
- 不要套 `.canvas { inset: 56px; border-radius: 32px; }` 这种内卡片——上线后被裁切就出 bug
- 字体用 Google Fonts 等 web 字体时，留 800ms 延迟等加载（Playwright `networkidle` 之后再 wait）
- 用 deviceScaleFactor: 1 而非 2——sspai 不需要 retina 大文件

## 题图上传 UI 流程

少数派的题图上传**不在 CKEditor 内**，是独立的上传区。三步：

1. 点 **「替换图片」** 按钮（如果是首次，按钮可能是「上传题图」）
2. 浏览器弹文件选择器，选 PNG
3. 弹**裁切弹窗**，点 **「裁切并使用」** 确认

playwriter 模式：

```js
const fileChooserPromise = page.waitForEvent('filechooser');
await page.click('.upload-image-container button:has-text("替换图片")');
const fileChooser = await fileChooserPromise;
await fileChooser.setFiles(coverPath);
await page.waitForSelector('button:has-text("裁切并使用")');
await page.click('button:has-text("裁切并使用")');
```

### 不要做的

- ❌ 用 `.upload-input` 直接 `setInputFiles`：会跳过裁切流程，最终成图比例错乱
- ❌ 不点「裁切并使用」就直接走下一步：题图状态停留在「待裁切」，发布时会报错
- ❌ 题图传完不验证：刷新一次或读取 thumbnail src 确认上传成功

## 多版本题图建议

如果有多个候选海报，**先在本地都渲染出来，并排展示给用户挑**——而不是每次只生成一张。常见维度：

- 中心式 vs 编辑式（不对称）
- 大字标题 vs Code-as-art
- 重视觉冲击 vs 重信息密度

这一点对项目宣传贴尤其重要——题图是少数派列表页第一印象，质量影响点击率。
