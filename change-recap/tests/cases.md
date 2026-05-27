# change-recap Test Cases

按场景分组:触发 / 受众 / 长度护栏 / 非 UI 边界 / 编排联动。

---

## Trigger Tests

### Case 1: 正例触发 — 显式 "讲一下"

- 输入:用户说"刚修了那个登录卡顿的 bug,讲一下"
- 预期:
  - mode: change-recap 显式触发
  - 收集 git diff
  - task_type 推断为 bugfix
  - audience 默认 end-user
  - 输出 3 段 markdown

### Case 2: 正例触发 — 显式 "recap 这次改动"

- 输入:用户说"merge 完了,recap 一下这次改动"
- 预期:
  - mode: change-recap
  - task_type 推断为 merge-resolve(关键词 "merge 完了")
  - 输出含"两边的意图 / 取舍"语义

### Case 3: 反例触发 — "为啥这段代码这样写"

- 输入:用户说"为啥这段代码用了 useEffect?"
- 预期:
  - **不**进 change-recap(那是代码 walkthrough,应用 `教` hat)
  - 不收集 git diff,直接走普通解释

### Case 4: 反例触发 — 改动还没发生

- 输入:用户说"等下要修 X,讲讲准备怎么做"
- 预期:
  - **不**进 change-recap(改动还没发生,recap 的对象是已发生改动)
  - 应走 plan / brainstorm 类 skill

---

## Audience Tests

### Case 5: end-user 受众(默认)

- 输入:用户说"recap 一下"(无显式 audience)
- diff 内容:fix race condition in payment checkout
- 预期:
  - audience = end-user
  - 输出**不含**:race condition / mutex / Promise / payment.ts:128
  - 输出**可含**:"结算" / "下单" / "卡顿" / "等几秒"
  - 例输出:
    ```
    ## 症状场景
    下单时偶尔会卡 3-5 秒。
    ## 根因
    两个请求抢同一个资源,谁先到谁等。
    ## 现在的行为
    下单 1 秒内完成,不再卡。
    ```

### Case 6: pm 受众

- 输入:`change-recap --audience pm`
- 同样的 diff
- 预期:
  - audience = pm
  - 输出**可含**:"结算流程" / "并发延迟" / "高并发场景"
  - 输出**不含**:file:line / 框架名 / 变量名
  - 例输出:"结算在高并发时偶现 3-5 秒延迟 / 竞态条件互相阻塞 / 现降到 < 1 秒"

### Case 7: dev 受众

- 输入:`change-recap --audience dev`
- 同样的 diff
- 预期:
  - audience = dev
  - 输出**可含**:模块名 + 行为描述(如 "checkout endpoint 同步锁 → 无锁队列")
  - 输出**不含**:file:line(dev 自己 git diff)

---

## Length Guard Tests

### Case 8: 护栏 — 超 200 字符自检失败

- 模拟:agent 第一版输出 280 字符
- 预期:
  - 自检 `within_length: false`
  - 当场重写,不输出"建议你自己看"

### Case 9: 护栏 — end-user 受众含技术 jargon

- 模拟:agent 第一版 end-user 输出含 "stale closure"
- 预期:
  - 自检 `no_tech_jargon: false`
  - 重写翻成"按钮偶尔点了没反应"

### Case 10: 护栏 — 输出含 file:line

- 模拟:agent 输出含 "PaymentForm.tsx:128"
- 预期:
  - 自检 `no_file_line: false`(任何 audience)
  - 重写去掉

### Case 11: 护栏 — 三段缺一段

- 模拟:agent 只输出"症状场景"+"现在的行为",缺"根因"
- 预期:
  - skill-doctor / 自检拦住
  - 补回"根因"段

---

## 非 UI 边界 Tests

### Case 12: 非 UI 改动 — 正常处理

- diff 内容:`src/services/payment.ts` 改 race condition
- 预期:
  - Step 2 探测无 .tsx/.css → 不提示
  - 正常输出 3 段

### Case 13: 纯 UI 改动 — 降级提示

- diff 内容:仅 `src/components/Header.tsx` 颜色 + 间距调整
- 预期:
  - Step 2 探测全是 UI 文件
  - 输出降级提示:"建议改用 director-design + 截图"
  - 等用户回"继续"才进 Step 3
  - 用户拒 → 退出建议改 director-design

### Case 14: 混合改动(UI + 逻辑)

- diff 内容:`Header.tsx` + `services/auth.ts` 都改了
- 预期:
  - Step 2 探测有 UI 但不全是
  - 不降级,正常处理(以逻辑改动为主讲)

---

## 编排联动 Tests(flow-dev-task → change-recap)

### Case 15: flow-dev-task auto-recap=true(默认)bugfix

- 前置:flow-dev-task Stage 8 commit 前
- task_type=bugfix,`--auto-recap` 未指定(默认 true)
- 预期:
  - flow-dev-task 自动调 change-recap
  - audience 透传(若 flow-dev-task `--audience pm` 则 change-recap audience=pm)
  - change-recap 输出 markdown 返回 flow-dev-task
  - flow-dev-task 推 IM(若 IM 会话)
  - 然后才走 Stage 8 clean-commit

### Case 16: flow-dev-task auto-recap=false

- 前置:用户 `todo-flow exec --auto-recap=false` 或 `flow-dev-task --auto-recap=false`
- task_type=bugfix
- 预期:
  - flow-dev-task **不调** change-recap
  - 直接走 Stage 8 clean-commit
  - 用户可后续手工 `change-recap` 显式调

### Case 17: task_type=feature(新加 feature)

- 前置:flow-dev-task Stage 8,task_type=feature
- `--auto-recap=true`
- 预期:
  - flow-dev-task **不调** change-recap(task_type 不在 bugfix/merge/accept-review-feedback 列表)
  - 直接走 Stage 8 clean-commit

### Case 18: change-recap 生成失败 fallback

- 前置:change-recap LLM 调用报错 / token 超
- 预期:
  - flow-dev-task **不阻断** Stage 8
  - 跳过 IM 推送 + commit body 不拼 recap
  - 走 Stage 8 clean-commit
  - 在 Final Report `errors[]` 标记"change-recap failed: <reason>"

---

## Output Contract Tests

### Case 19: 输出 JSON 字段完整

- 输入:任意正例触发
- 预期 JSON 含全 fields:
  - skill / audience / task_type / is_ui_change / ui_warning_shown
  - recap_markdown / char_count / self_check (4 子字段)
  - im_pushed / next_action

### Case 20: skill-doctor lint 通过

- 输入:`node ~/Documents/projects/node-scripts/dist/skill-doctor/index.js --root ~/Documents/projects/skills`
- 预期:change-recap 0 ERROR
- description 长度 < 800 soft warn / < 1000 hard error
