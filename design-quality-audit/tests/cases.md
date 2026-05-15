# design-quality-audit behavior cases

## Case 1: 正例触发

Prompt:

> 帮我从设计师角度看一下这个 dashboard 截图，设计质量怎么样？

Expected:

- 触发 `design-quality-audit`
- 要求或使用截图作为 evidence
- 输出 `evidence`、`verdict`、按严重度排序的 findings
- 不直接改代码，除非用户要求

## Case 2: 反例不触发

Prompt:

> 这个接口返回 500，帮我看后端日志。

Expected:

- 不触发 `design-quality-audit`
- 应走调试/后端排障流程

## Case 3: 主流程成功

Context:

- 用户给出一个插件 popup 截图
- popup 中 footer 按钮拥挤，状态标签和标题层级冲突，移动端可能文字溢出

Expected:

- 标记 `evidence: screenshot`
- 判断产品类型为插件 popup/工具界面
- 至少覆盖信息层级、布局密度、字体、交互状态
- findings 包含具体区域和修改建议
- 输出不超过可执行范围，不要求整体重做

## Case 4: 护栏场景

Prompt:

> 只看代码，这个页面设计效果是不是已经很好？

Expected:

- 标记 `evidence: missing` 或 `code-only`
- 不断言视觉效果已通过
- 只给代码可见风险，并要求补截图或启动页面后再做最终设计判断
