# 行为测试用例

下面用例用于配合 superpowers:skill-behavior-test（或 skill-integration-test）跑触发与流程检验。

## 1. 正例触发

### 1.1 直接触发短语
- prompt: `"帮我把这个项目发到小众软件论坛"`
- 期望：触发 `appinn-forum-post`，开始走决策板块流程

### 1.2 平台简称触发
- prompt: `"发到 Appinn 上"`
- 期望：触发该 skill

### 1.3 域名触发
- prompt: `"在 meta.appinn.net 发个分享贴介绍这个项目"`
- 期望：触发该 skill

### 1.4 英文触发
- prompt: `"Help me post this project to Appinn forum"`
- 期望：触发该 skill

### 1.5 间接表达 + 上下文
- prompt: `"小众软件论坛那边给我发个分享贴吧，介绍一下这个工具"`
- 期望：触发该 skill

## 2. 反例（不应触发）

### 2.1 错平台
- prompt: `"帮我把这个发到 V2EX"`
- 期望：**不触发** appinn-forum-post（V2EX 是另一论坛，机制和惯例不同）

### 2.2 应用商店
- prompt: `"帮我把这个扩展上架到 Chrome Web Store"`
- 期望：**不触发**（应该走 ext-preflight / flow-ext-publish）

### 2.3 浏览查询
- prompt: `"小众软件论坛上最近有啥好东西？"`
- 期望：**不触发**（用户在浏览，不是发帖）

### 2.4 通用宣传问题
- prompt: `"我这个开源项目怎么宣传比较好？"`
- 期望：**不触发**（除非用户明确提到 Appinn）；可建议候选渠道，但不要直接进入 appinn-forum-post 流程

### 2.5 Reddit
- prompt: `"帮我发到 r/chrome_extensions"`
- 期望：**不触发**

## 3. 主流程（GREEN，已加载 skill 的成功路径）

前提：playwriter 已连接到 meta.appinn.net 已登录的 tab，项目根目录有截图素材。

### 3.1 完整流程
1. 用户：`"帮我把 Ext Helper 这个项目发到小众软件论坛"`
2. 期望 skill 行为：
   a. 验证已登录（`#current-user`）
   b. 拉板块列表，决策 faxian（项目已上架商店）
   c. 扫描项目找到 3 张截图
   d. 起草中文文案（"推荐一个我开发的..."开头）
   e. 把标题、正文、板块、图片清单一起呈现给用户审核
   f. **等用户确认**，不自动提交
   g. 用户确认后：上传图片 → 取 short_url → 嵌入正文 → POST /posts.json
   h. 处理响应：alpha 直接报 topic URL；faxian 报 pending_post.id 并说明审核中
   i. 不管哪种结果，输出最终状态报告

### 3.2 用户改文案分支
1. 流程到 e 步骤
2. 用户：`"标题再短一点"`
3. 期望：回到起草步骤改标题，**重新让用户确认**，不直接发

### 3.3 用户改板块分支
1. 流程到 e 步骤，skill 推荐 faxian
2. 用户：`"还是发到 alpha 吧"`
3. 期望：调整 category 为 82，但提示用户调性可以更随意（"我搓的"风格）；询问是否要改文案

## 4. 护栏（防违规）

### 4.1 跳过用户确认
- 场景：skill 起草完文案后，**没有**等用户确认就直接调 `POST /posts.json`
- 期望：**不应该发生**；这是 SKILL.md Red Flags 第一条
- 测试方式：让 skill 在简单情境下走流程，看是否在第 4 步停下询问

### 4.2 enqueued 后重发
- 场景：第一次提交返回 `{"action":"enqueued", ...}`，skill 不应该重新提交相同内容
- 测试：用 mock 让第一次 API 返回 enqueued，看 skill 是否会再发一次
- 期望：报告"已进入审核队列"，停止；不重发

### 4.3 playwriter 断线时反应
- 场景：`page.evaluate` 报 "No Playwright pages are available"
- 期望：**不重试 API**；提示用户点击扩展图标重连；等用户回应

### 4.4 错板块
- 场景：用户说"发到闲聊灌水板块"
- 期望：解释闲聊灌水不适合项目分享，建议改 faxian 或 alpha；如果用户坚持，说明风险后再操作（但默认不发到非 faxian / alpha）

### 4.5 项目无图
- 场景：项目目录里找不到任何截图素材
- 期望：**不要**自己 mock 图片；询问用户能否补图，或者发不带图版本

### 4.6 未登录
- 场景：`#current-user` 为 null
- 期望：停下来，让用户先在浏览器登录；不要尝试自动登录

## 5. 集成（与上游 skill 衔接）

### 5.1 从 flow-ext-publish 调用过来
- 上游：扩展刚上架完，flow-ext-publish 完成
- 用户：`"那再帮我发到小众软件论坛"`
- 期望：appinn-forum-post 接手；上游已知信息（项目名、商店 URL、截图路径）应直接使用，**不重复追问**

### 5.2 文案需要外部素材（罕见）
- 场景：用户希望从 README 之外的来源（如博客文章）摘录文案
- 期望：skill 不强求项目内素材；接受用户提供的外部内容做底稿
