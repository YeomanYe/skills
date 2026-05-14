# Codex `/goal` 启用步骤

`/goal` 是 Codex CLI **0.128.0+** 的实验功能，默认关闭。本文档是 Pre-flight 检查脚本可调用的步骤。

## 1. 版本检查

```bash
CODEX_VERSION=$(codex --version | awk '{print $2}')
REQUIRED="0.128.0"

# semver 比较
if [[ "$(printf '%s\n' "$REQUIRED" "$CODEX_VERSION" | sort -V | head -1)" != "$REQUIRED" ]]; then
  echo "Codex CLI $CODEX_VERSION < $REQUIRED — please upgrade:"
  echo "  brew upgrade codex   # or"
  echo "  npm install -g @openai/codex@latest"
  exit 1
fi
```

## 2. Feature flag 启用

`/goal` 必须在 `~/.codex/config.toml` 启用：

```toml
[features]
goals = true
```

自动检测 + 写入：

```bash
CONFIG="$HOME/.codex/config.toml"
mkdir -p "$(dirname "$CONFIG")"
touch "$CONFIG"

if ! grep -q "^goals\s*=\s*true" "$CONFIG"; then
  if grep -q "^\[features\]" "$CONFIG"; then
    # [features] 段已存在，在段下加
    sed -i '' '/^\[features\]/a\
goals = true
' "$CONFIG"
  else
    # 追加新段
    cat >> "$CONFIG" <<'EOF'

[features]
goals = true
EOF
  fi
  echo "Enabled goals feature in $CONFIG"
fi
```

## 3. 登录态检查

```bash
codex login --status 2>&1 | grep -q "Logged in" || {
  echo "Codex not logged in. Run: codex login"
  exit 1
}
```

## 4. App-server 模式（程序化派工备选）

如果选择程序化（不走交互式 `/goal`），用 app-server：

```bash
codex app-server --capabilities experimentalApi &
APP_SERVER_PID=$!
sleep 2

# 通过 thread/goal/set API 设置 goal
# 详见 https://developers.openai.com/codex/cli/app-server
```

API 列表（experimental）：
- `thread/goal/set`
- `thread/goal/get`
- `thread/goal/clear`

## 5. 失败 fallback

任一检查失败 → 整个 flow-codex-goal skill 退出，建议改用 `flow-dev-task` + orchestrator agent 自写。

## 参考

- Codex 官方文档：https://developers.openai.com/codex/cli/slash-commands
- Codex `/goal` use case：https://developers.openai.com/codex/use-cases/follow-goals
- Simon Willison 介绍：https://simonwillison.net/2026/Apr/30/codex-goals/
- 实现 PR 分析：https://gist.github.com/patleeman/b1b5768393f9bf2f60865b1defeeb819
