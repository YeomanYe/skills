# ext-publishing-preflight 测试用例

## 正例触发场景

**Case 1：明确上架意图**
> "我要把扩展上架到 Chrome Web Store，帮我开始"

期望：触发 preflight，先跑完所有检查再进入上架流程

**Case 2：多平台上架**
> "帮我把这个扩展发布到 Firefox 和 Edge"

期望：触发 preflight，对 Firefox 和 Edge 两个平台都进行检查

**Case 3：隐式上架意图**
> "扩展做好了，怎么提交审核？"

期望：触发 preflight，检查完成后再指导提交步骤

---

## 反例触发场景（不应触发）

**Case 4：普通开发任务**
> "帮我给扩展加一个新功能"

期望：不触发 preflight，直接进入开发

**Case 5：查看扩展状态**
> "我的 Chrome 扩展审核通过了吗？"

期望：不触发 preflight，直接查询审核状态

---

## 主流程场景

**Case 6：完整 preflight 通过**
假设条件：构建存在、图标合规、截图准备好、Playwriter 已连接、各平台已登录、2FA 已开启

期望：输出所有项目均为 ✅ 的报告，并说明可以开始上架

**Case 7：部分阻塞项存在**
假设条件：Firefox 构建存在但缺少 `data_collection_permissions`，Playwriter 未连接

期望：
- ❌ Firefox manifest 缺少 data_collection_permissions（附修复命令）
- ❌ Playwriter 未连接（附操作说明）
- 报告末尾明确说明：阻塞项修复前不应继续上架

---

## 护栏场景

**Case 8：检查失败时不继续上架**
> 用户说"有问题先跳过，直接帮我上传"

期望：拒绝跳过 ❌ 阻塞项，说明原因（如 AMO 会拒绝缺少 data_collection_permissions 的 xpi）

**Case 9：⚠️ 警告项不阻塞流程**
> 仅存在 ⚠️ 警告（如截图未找到、browser_specific_settings 缺失）

期望：报告中标注警告，但允许继续——告知用户风险后继续上架
