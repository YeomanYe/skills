# 项目图片自动发现

## 扫描位置（按优先级降序）

```
1. README.md / README.zh.md / README.zh-CN.md 中 ![](...) 引用的图片路径
2. website/public/screenshots/
3. website/public/store/
4. screenshots/
5. assets/screenshots/
6. store-assets/  /  store/
7. docs/images/  /  docs/screenshots/
8. public/screenshots/
```

## 扫描脚本（建议用 Glob + Read）

```
Glob: **/screenshot*.{png,jpg,jpeg,webp}
Glob: **/store/**.{png,jpg,jpeg}
Read README.md → 提取所有 ![alt](path) 中的相对路径
```

## 文件名 → 中文 alt 启发式

发现项目中的截图后，按文件名映射成有意义的中文 alt：

| 文件名（小写、去扩展名） | 候选 alt |
|---|---|
| `screenshot-card`, `card`, `cards`, `card-view` | 卡片视图 / 分组卡片视图 |
| `screenshot-bisect`, `bisect`, `debug` | Bisect 调试 / 调试器 |
| `screenshot-rules`, `rules`, `rule`, `automation` | 自动规则 / 规则编辑器 |
| `screenshot-main`, `main`, `home`, `index` | 主界面 |
| `screenshot-list`, `list` | 列表视图 |
| `screenshot-group`, `groups`, `groups-bar` | 分组管理 |
| `screenshot-popup`, `popup` | 弹窗 |
| `screenshot-settings`, `settings`, `options`, `preferences` | 设置 |
| `screenshot-dark`, `dark`, `dark-mode` | 暗色模式 |
| `screenshot-light`, `light`, `light-mode` | 浅色模式 |
| `screenshot-mobile`, `mobile` | 移动端 |
| `hero`, `cover`, `banner`, `og` | （主视觉，通常不嵌正文） |
| `icon`, `logo` | （图标/logo，通常不嵌正文） |

## 不应嵌入正文的图片

- `hero-poster.png` / `cover.png` / `banner.png` / `og-image.png` —— 营销视觉，不是功能演示
- `icon.png` / `logo.png` —— 图标
- 尺寸 < 200×200 —— 小图标，没意义
- 文件大小 > 5MB —— Discourse 默认上限，先警告用户

## 优先用部署后的公网 URL

如果项目有 GitHub Pages / Vercel / 自部署官网，**优先用线上 URL**，原因：
- 不需要 base64 编码
- 上传请求体小，更快
- 出错时调试简单

判断方法：
1. 读 `package.json` 里 `homepage` 字段
2. 读 README 里 GitHub Pages / Vercel 的链接
3. HEAD 请求验证 URL 可访问

```js
page.evaluate(async (url) => {
  const r = await fetch(url, {method:'HEAD'});
  return {status: r.status, type: r.headers.get('content-type')};
}, 'https://example.github.io/proj/screenshots/foo.png')
```

## 图片配对：每张图配什么功能说明

发帖正文按"功能 → 图片"穿插（参考 post-style.md 的模板）。配对原则：

1. README 表格里如果已经标注了图与功能的对应（例 `| Card View | Bisect Debugger | Auto Rules |`），照搬
2. 否则用文件名启发式 + 项目核心功能列表交叉匹配
3. 实在配不上的图，让用户决定要不要嵌、嵌哪里

## 用户审核环节必须做

把发现结果以这种形式给用户看：

```
找到 3 张项目素材图：
  1. screenshots/screenshot-card.png    → 拟用 alt: "分组卡片视图"     → 配在 [分组管理] 段后
  2. screenshots/screenshot-bisect.png  → 拟用 alt: "Bisect 调试"      → 配在 [Bisect 调试] 段后
  3. screenshots/screenshot-rules.png   → 拟用 alt: "自动规则"          → 配在 [自动规则] 段后

需要：
- 调整顺序？
- 改 alt？
- 删除某张 / 添加新图？
```

不要默认接受自动配对的结果，但也不要每张图都问一次——一次性展示让用户一次决定。
