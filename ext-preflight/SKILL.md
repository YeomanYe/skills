---
name: ext-preflight
description: Use when about to publish or submit a browser extension to Chrome Web Store, Firefox AMO, or Microsoft Edge Add-ons — triggered by phrases like "上架扩展", "提交到商店", "发布扩展", "准备上架", "帮我上架", "submit extension", "publish extension", or any intent to submit a browser extension to a store. Do NOT trigger for general extension development, code changes, or reviewing extension status.
---

## 这个 Skill 做什么

在正式开始扩展上架之前，跑完所有前置检查项，输出一份明确的通过/失败报告。
**所有 ❌ 阻塞项必须先修复，才能进入上架流程。⚠️ 警告项不阻塞，告知风险后可继续。**

---

## 前置：确认目标平台

先询问用户本次要上架哪些平台（不一定三个都需要），并确认：

- 构建产物路径（如 `build/chrome-mv3-prod/`）
- 本项目的构建命令（如 `pnpm build`、`npm run build:firefox` 等）
- .xpi 或 .zip 包的打包方式

以下各步骤中的命令均为示例，**应根据用户项目的实际路径和工具替换**。

---

## 第一步：检查构建产物

针对每个目标平台，检查构建输出目录中是否存在 `manifest.json`：

```bash
# 示例：Chrome MV3（路径因项目而异）
ls <chrome-build-dir>/manifest.json 2>/dev/null \
  && echo "✅ Chrome 构建存在" \
  || echo "❌ Chrome 构建缺失 — 执行：<build-command>"

# 示例：Firefox（路径因项目而异）
ls <firefox-build-dir>/manifest.json 2>/dev/null \
  && echo "✅ Firefox 构建存在" \
  || echo "❌ Firefox 构建缺失"

# 示例：Firefox .xpi 打包检查
ls /tmp/<ext-name>.xpi 2>/dev/null \
  && echo "✅ .xpi 已打包" \
  || echo "⚠️  .xpi 未打包 — 执行：cd <firefox-build-dir> && zip -r /tmp/<ext-name>.xpi ."
```

---

## 第二步：检查资源文件

各平台所需截图尺寸不同，一并检查：

```bash
python3 -c "
from PIL import Image
import glob, os

# 检查 icon（所有平台均需要 ≥ 128x128）
icon_paths = ['assets/icon.png', 'src/assets/icon.png', 'public/icon.png']
for p in icon_paths:
    if os.path.exists(p):
        img = Image.open(p)
        w, h = img.size
        if w >= 128 and h >= 128:
            print(f'✅ Icon 合规：{p} ({w}x{h})')
        else:
            print(f'❌ Icon 尺寸不足：{p} ({w}x{h})，最小需要 128x128')
        break
else:
    print('❌ 未找到 icon.png')

# 检查截图（搜索常见目录）
search_dirs = ['/tmp', 'assets', 'screenshots', 'store-assets']
sizes_needed = {
    (1280, 800): 'Chrome Web Store 截图 / Firefox AMO 截图（必须）',
    (440, 280):  'Chrome Web Store 小宣传图（Small promo tile）',
    (1400, 560): 'Chrome Web Store 大横幅（Marquee promo tile）',
}
found = set()
for d in search_dirs:
    for f in glob.glob(f'{d}/*.png') + glob.glob(f'{d}/*.jpg'):
        try:
            img = Image.open(f)
            if img.size in sizes_needed:
                print(f'✅ {img.size[0]}x{img.size[1]} — {sizes_needed[img.size]}：{f}')
                found.add(img.size)
        except: pass

for size, desc in sizes_needed.items():
    if size not in found:
        sym = '❌' if size == (1280, 800) else '⚠️ '
        print(f'{sym} 未找到 {size[0]}x{size[1]} — {desc}')
"
```

> 若 PIL 未安装：`pip3 install pillow`

**Chrome Web Store 截图尺寸说明：**
| 尺寸 | 用途 | 必须 |
|------|------|------|
| 1280x800 | 详情页截图（最多 5 张） | ✅ |
| 440x280 | Small promo tile（搜索结果卡片） | ⚠️ 建议 |
| 1400x560 | Marquee promo tile（首页横幅） | ⚠️ 建议 |

---

## 第三步：检查 Firefox Manifest 特殊字段

仅在目标平台包含 Firefox AMO 时执行：

```bash
python3 -c "
import json
try:
    with open('<firefox-build-dir>/manifest.json') as f:
        m = json.load(f)
    if 'data_collection_permissions' in m:
        print('✅ data_collection_permissions 已存在')
    else:
        print('❌ data_collection_permissions 字段缺失 — Firefox AMO 会拒绝上传')
        print('   修复：在 manifest.json 中添加 {\"data_collection_permissions\": {\"collected\": []}}')
    if 'browser_specific_settings' in m or 'applications' in m:
        print('✅ Firefox 专属配置已存在')
    else:
        print('⚠️  未找到 browser_specific_settings — 建议添加 gecko.id 以稳定扩展 ID')
except FileNotFoundError:
    print('❌ Firefox 构建目录不存在，请先构建')
"
```

---

## 第四步：检查 Playwriter 连接状态

```bash
npx playwriter@latest session new 2>&1
```

| 结果 | 状态 | 处理方式 |
|------|------|---------|
| `Extension connected` | ✅ 已连接 | 可继续 |
| `Extension did not connect within timeout` | ❌ 未连接 | 在浏览器中点击 Playwriter 扩展图标 |
| `ECONNREFUSED` | ❌ Debug Chrome 未运行 | 参考 `cdp-browser-control` skill 启动 Chrome |

---

## 第五步：检查各平台登录状态

**Firefox AMO / Edge 合作伙伴中心**：可通过 playwriter 导航到验证 URL 并截图确认：

```javascript
const pages = context.pages();
pages.forEach((p, i) => console.log(i, p.url()));
```

| 平台 | 验证 URL | ✅ 登录成功信号 |
|------|---------|--------------|
| Firefox AMO | `https://addons.mozilla.org/developers/` | 右上角显示用户名，页面显示「我的附加组件」 |
| Edge 合作伙伴中心 | `https://partner.microsoft.com/dashboard/microsoftedge/overview` | 进入扩展管理页（不跳转回主页） |

**Chrome Web Store**：Google 会拦截自动化导航，无法通过 playwriter 直接验证登录状态。
改为提醒用户手动确认：

> ⚠️ 请在真实 Chrome 浏览器中手动确认：已登录发布用的 Google 账号，
> 并可以正常访问 `https://chrome.google.com/webstore/devconsole`。

---

## 第六步：检查平台特定前置条件

### Firefox AMO

- **2FA（❌ 阻塞）**：AMO 要求提交前必须开启二步验证
  - 检查：尝试点击「提交」，若跳转到 `accounts.firefox.com/inline_totp_setup` 则未开启
  - 修复：用户手动在 accounts.firefox.com 完成绑定（需要身份验证器 App）

- **开发者协议（❌ 阻塞）**：首次提交需接受分发协议

### Microsoft Edge

- **计划注册（❌ 阻塞）**：账号需先注册 Edge Add-ons 计划
  - 检查：访问 `/dashboard/microsoftedge/overview` 若重定向到 `/dashboard/home` 则未注册
  - 修复：合作伙伴中心主页 → 点「+」→ 选择 Microsoft Edge 项目 → 完成注册

### Chrome Web Store

- **开发者账号（❌ 阻塞）**：需完成一次性 $5 注册费
- **隐私政策（❌ 阻塞）**：使用 `<all_urls>` 权限时必须填写隐私政策 URL
- **Google 账号 2FA（❌ 阻塞）**：发布用的 Google 账号必须开启两步验证

---

## 护栏规则

- ❌ 项存在时，**禁止继续上架**，即使用户要求跳过也应拒绝并说明原因
- ⚠️ 项存在时，**告知风险后允许继续**，不强制阻塞
- 所有检查必须实际执行（跑命令/截图/手动确认），不能只给建议

---

## 输出格式

```
## Preflight 检查报告

### 目标平台
- 本次上架：Chrome Web Store / Firefox AMO / Microsoft Edge（按实际）

### 构建产物
- [✅/❌] Chrome 构建
- [✅/❌] Firefox 构建
- [✅/⚠️] Firefox .xpi 已打包

### 资源文件
- [✅/❌] Icon ≥ 128x128
- [✅/❌] 截图 1280x800（必须）
- [✅/⚠️] 截图 440x280（Chrome 小宣传图）
- [✅/⚠️] 截图 1400x560（Chrome 大横幅）

### Manifest
- [✅/❌] Firefox：data_collection_permissions
- [✅/⚠️] Firefox：browser_specific_settings

### 工具连接
- [✅/❌] Playwriter 扩展已接入

### 平台登录
- [✅/⚠️] Chrome Web Store：用户手动确认已登录
- [✅/❌] Firefox AMO 已登录
- [✅/❌] Edge 合作伙伴中心 已登录

### 平台前置条件
- [✅/❌] Firefox：2FA 已开启
- [✅/❌] Firefox：分发协议已接受
- [✅/❌] Edge：Microsoft Edge 计划已注册
- [✅/❌] CWS：开发者账号已注册（$5）
- [✅/❌] CWS：隐私政策 URL 已填写

### 阻塞项（❌）
列出所有失败项及对应的修复步骤。
**阻塞项全部修复后，才可以继续上架流程。**

### 结论
- 是否可以开始上架：是 / 否（N 个阻塞项待修复）
```

---

## 常见问题速查

| 问题 | 修复方法 |
|------|---------|
| 构建缺失 | 用本项目构建命令重新构建 |
| .xpi 未打包 | `cd <firefox-build-dir> && zip -r /tmp/<name>.xpi .` |
| `data_collection_permissions` 缺失 | manifest 添加 `{"data_collection_permissions": {"collected": []}}` 后重新打包 |
| Playwriter 未连接 | 在浏览器中点击 Playwriter 扩展图标 |
| Firefox 2FA 未开启 | 用户手动在 accounts.firefox.com 完成绑定 |
| Edge 计划未注册 | 合作伙伴中心 → 「+」→ Microsoft Edge |
| AMO 上传 503 | Mozilla 服务器临时故障，等待后重试 |
| Chrome 登录无法自动验证 | 用户手动在真实 Chrome 中确认登录状态 |
