# IM 证据回传实现参考

本文件是 `delivery-gate` skill 第二阶段"IM 证据回传"的实现细节补充。

## 触发判定

检查 `CC_SESSION_KEY` 环境变量：

```bash
case "$CC_SESSION_KEY" in
  feishu:*)   CHANNEL=feishu ;;
  telegram:*) CHANNEL=telegram ;;
  discord:*)  CHANNEL=discord ;;
  wechat:*)   CHANNEL=wechat ;;
  qq:*)       CHANNEL=qq ;;
  *)          CHANNEL=""; echo "skipped (non-IM session)" ;;
esac
```

目标频道 ID 通常可从 `CC_SESSION_KEY` 解析，例如 `feishu:chat:oc_xxxxxx`。

## 飞书（首选实现）

使用 `lark-cli` 的 `im` 命令（参见 `lark-im` skill）。

### 上传并发送图片

```bash
lark im +upload-image --file "<path>" --chat-id "<chat-id>"
```

### 上传并发送视频（优先尝试）

```bash
lark im +send-file --file "<path>" --chat-id "<chat-id>"
```

飞书消息 API 支持的视频格式与大小有限，推荐：

- 容器：mp4（H.264 + AAC）
- 单条消息文件大小通常 ≤ 30MB
- 超限或格式不符会返回 `99991400` / `230001` 等错误码

### 视频发送失败 → gif 降级

检查返回码，非 0 或 API 报错即触发降级。

降级命令：

```bash
ffmpeg -i "<video>" \
  -vf "fps=10,scale=480:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" \
  "<video>.gif"
```

再次尝试：

```bash
lark im +upload-image --file "<video>.gif" --chat-id "<chat-id>"
```

若 gif 仍超限（飞书图片通常 ≤ 10MB），按以下顺序再降：

1. fps 10 → 8，宽度 480 → 360
2. fps 8 → 6，宽度 360 → 240
3. 用 ffmpeg 抽 3-5 张关键帧发送：

```bash
ffmpeg -i "<video>" -vf "select='eq(pict_type,I)',scale=720:-1" -vsync vfr "<video>-frame-%02d.jpg"
```

## Telegram / Discord / WeChat / QQ

这些平台多数有独立的 bot API 或第三方 CLI，实现时按通道替换。通用规则：

- 先尝试原始视频
- 失败 → 转 gif 再试
- gif 失败 → 关键帧图片集

本 skill 不强制绑定具体 CLI 实现，按环境存在的工具选择。

## 附件筛选

只发送"本次 gate 期间新产生"的证据：

- 推荐路径约定：Playwright 输出到 `.tmp/playwright/<timestamp>/`
- 按 mtime 过滤：`find .tmp/playwright -mmin -30 -type f`
- 或显式由上游传入路径列表

不得：

- 扫描 `.env`、`credentials`、`*.key`、`*.pem` 等敏感文件
- 发送任何 `.git/` 下的文件
- 发送大于 IM 平台上限的原始文件前不做降级尝试

## 输出

每个附件必须记录一行状态：

```
<path>: sent | fallback-gif | fallback-frames | failed(<reason>)
```

示例：

```
.tmp/playwright/2026-04-21/checkout-main.png: sent
.tmp/playwright/2026-04-21/checkout-crud.mp4: fallback-gif
.tmp/playwright/2026-04-21/oversized.mp4: failed(exceeds-size-after-all-fallbacks)
```

## 幂等与重试

- 每条消息附带本次 gate 的 run-id（例如 commit-sha 或 timestamp）避免重复发送
- 单条附件失败不阻塞其他附件
- 整体 IM 回传失败不阻断 gate 结论
