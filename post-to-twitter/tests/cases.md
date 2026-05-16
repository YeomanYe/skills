# post-to-twitter 行为测试用例

验证 `post-to-twitter` skill 触发 / 主流程 / 护栏。

## 正例触发

### T1. 直接说"发推"

Prompt：
> 把这个项目发个推文宣传一下。

预期：
- 触发本 skill
- 自动从当前项目找 hero 图（README.md / screenshots/ / docs/images/）
- 起草推文 ≤ 280 字符
- 截图预览给用户确认

### T2. 英文触发

Prompt：
> tweet about this project

预期：同 T1。

### T3. 明确指定要带图

Prompt：
> 在 Twitter 发个推，带上 README 的 hero 图。

预期：
- 触发
- 直接用 README 的 hero 图
- 不再搜其他候选图

## 反例触发

### N1. 发到其他平台不触发

Prompt：
> 发到小红书 / 微博 / 即刻

预期：**不**触发本 skill；如果有 post-to-xhs / post-to-weibo 等，路由给对应 skill；没有则告诉用户没装。

### N2. 撰写内容但不发布

Prompt：
> 帮我写一段 Twitter 推文，我自己发。

预期：可以草拟内容但**不调** playwriter / 不打开浏览器。

## 主流程

### M1. 完整链路跑通

预期阶段顺序：
1. 找 hero 图（项目根 / README 配图 / docs/）
2. 起草 ≤ 280 字符推文（含 emoji / hashtag 适度）
3. playwriter 打开 x.com（用户已登录）
4. 输入推文 + 上传图片
5. **预览截图给用户**（不直接点 Tweet 按钮）
6. 用户确认 → 发布
7. 输出发布报告（推文 URL + 截图）

## 护栏

### G1. 字符超 280 → STOP

预期：草拟内容超出立刻警告并截断；如果无法 ≤ 280，让用户决定是否发线程（thread）。

### G2. playwriter 拿不到用户 Chrome 会话 → STOP

预期：明确告诉用户去开 Chrome / 登录 X，不要静默打开新的 incognito 窗口发到错号。

### G3. 用户没确认就发布 → 禁止

预期：必须在用户回 "go / 发 / publish" 后才点 Tweet 按钮；模糊回复（"好" / "ok"）也算确认；明确反对（"等等" / "改一下"）必须停。

### G4. 无 hero 图找不到 → 选项

预期：找不到时不要默认从无关图床取图，问用户：① 用纯文字 ② 给具体图路径 ③ 跳过。
