# cdp-browser-control Test Cases

## 正例触发场景

**Case 1: Google 安全拦截**
> "我需要帮我自动化填写 Chrome Web Store 的上架表单，但之前 Playwright 打开的浏览器会被 Google 拦截说'此浏览器或应用可能不安全'，无法登录"

期望：触发 cdp-browser-control，执行 copy cookies → launch Chrome → session new --direct 流程

**Case 2: computer-use 只读**
> "computer-use 截图显示页面已经登录了，但我没办法点击，因为浏览器是 read-only tier，怎么操作这个页面？"

期望：触发 cdp-browser-control，说明需要用 CDP 直连方案

**Case 3: Chrome DevTools MCP session 隔离**
> "Chrome DevTools MCP 打开的页面总是跳到登录，但我已经在 Chrome 里登录了，怎么让它共享我的登录状态？"

期望：触发 cdp-browser-control，解释 session 隔离原因，提供 --direct 解决方案

---

## 反例触发场景（不应触发）

**Case 4: 无需登录的自动化**
> "帮我用 Playwright 爬取 https://example.com 的数据"

期望：不触发本 skill，直接用标准 Playwright MCP 或 playwriter

**Case 5: 正常 playwriter 任务**
> "用 playwriter 打开 Google.com 搜索一下天气"

期望：不触发本 skill，直接用 playwriter skill

---

## 护栏场景

**Case 6: 错误处理 - Browser context management**
> session 连接报错：`Protocol error (Browser.setDownloadBehavior): Browser context management is not supported`

期望：识别此错误，执行 pkill + relaunch + session new --direct

**Case 7: 错误处理 - WebSocket 404**
> playwriter 报错：`WebSocket 404 Not Found`

期望：识别 session 过期，直接 `session new --direct` 重连，无需重启 Chrome
