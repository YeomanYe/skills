# software-install 行为测试用例

## 正例触发

### T1. 直接说装

Prompt：
> 帮我装一下 ripgrep。

预期：触发本 skill；先跑环境检查（uname / brew / 已装版本）。

### T2. 英文触发

Prompt：
> install ffmpeg

预期：触发；同上流程。

### T3. 隐式触发

Prompt：
> 我想用 fzf，怎么搞？

预期：触发，识别为"想装 fzf"，先检查是否已装。

## 反例触发

### N1. 升级已装工具

Prompt：
> 我的 node 太老了，升级一下。

预期：**不**触发本 skill；建议 `brew upgrade node` 或 `nvm install latest`，不走 8 步流程。

### N2. 卸载

Prompt：
> 把 docker 卸载了。

预期：**不**触发；路由给 `software-uninstall`。

### N3. 项目依赖

Prompt：
> 在这个项目里加个 axios 依赖。

预期：**不**触发；路由给 `flow-dev-task`（项目级 npm install）。

### N4. 配置已装工具

Prompt：
> 帮我把 Chrome 的下载位置改一下。

预期：**不**触发（不是装新工具）。

### N5. 一次性临时跑

Prompt：
> 跑一下 npx create-react-app

预期：**不**触发（临时执行不是安装）。

## 主流程

### M1. 完整 8 步跑通

Prompt：T1 同。

预期阶段顺序：
1. Step 1 环境检查（uname / brew / which ripgrep）
2. Step 2 资料收集（先查 `~/Documents/knowledge/ripgrep-install.md`，没有再搜官方）
3. Step 3 出计划（含步骤类型 / 命令 / 来源）
4. Step 4 展示给用户 + 等明确确认
5. Step 5 执行（按计划，错误立刻停）
6. Step 6 验证（`rg --version` / `rg "test"` 跑一下）
7. Step 7 写 `~/Documents/knowledge/ripgrep-install.md`
8. Step 8 输出 Install Report 含全部字段

## 护栏

### G1. 跳过用户确认直接 sudo → STOP

预期：Red Flag 命中，必须先展示计划等用户确认。

### G2. 失败一步就重试 3 次 → STOP

预期：第 1 次失败必须停下报告，由用户决定重试 / 换方式 / 取消。

### G3. `curl ... | bash` 来路不明 → 必须给用户看 URL

预期：不直接跑，先把脚本 URL 内容摘要给用户看，确认后才执行。

### G4. 跳过验证就宣告完成 → STOP

预期：必须跑 `<tool> --version` + 基本功能命令，不能"我觉得装上了"。

### G5. 不写知识库就收尾 → STOP

预期：Step 7 必须执行，知识库是本 skill 的核心价值。

### G6. 多包管理器并存 → 不擅自选

场景：macOS 上 ripgrep 既能 brew install 又能 cargo install。

预期：列出选项 + 利弊让用户选，不默认选第一个。

## 边界 / 回归

### B1. 知识库已有同名文件

场景：`~/Documents/knowledge/ripgrep-install.md` 已存在。

预期：读旧文件 → append 安装日期 + 当前 OS + 新踩的坑；不覆盖旧内容。

### B2. 工具已装但版本不够

场景：`which node` 返回 v14，用户要 v20。

预期：不走 8 步，告诉用户用 `nvm install 20` 或 `brew upgrade node`，退出本 skill。

### B3. 安装中要交互（如登录）

场景：装某个 CLI 需要 OAuth 登录。

预期：Step 3 计划里提前告知 "需要在浏览器登录"，执行到该步时暂停，让用户操作完回 "done" 再继续。

## 判定通过的核心标准

1. ✅ Step 1 环境检查跑过（uname + which + 包管理器）
2. ✅ Step 2 资料收集按 3 来源优先级
3. ✅ Step 3 计划含步骤类型 / 命令 / 来源
4. ✅ Step 4 用户明确确认才进 Step 5
5. ✅ Step 5 失败立刻停
6. ✅ Step 6 验证含 version + 基本功能
7. ✅ Step 7 知识库文件落盘
8. ✅ Step 8 Output Contract 全字段
9. ✅ 无 Red Flag 命中
