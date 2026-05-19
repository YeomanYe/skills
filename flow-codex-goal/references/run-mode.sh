#!/usr/bin/env bash
# run-mode.sh — 三种运行模式探测
#
# 用法:
#   ./run-mode.sh detect       → 输出 CLI-YOLO | CLI-EXEC | SUBAGENT
#   ./run-mode.sh capabilities → 输出探测细节 JSON
#
# 三种模式：
#   CLI-YOLO   : 有 TTY + 终端 shell + worktree 隔离 OK，能 codex --yolo 长跑
#   CLI-EXEC   : 无 TTY 但能 spawn 子进程，每个 Phase 单次 codex exec
#   SUBAGENT   : 主进程能派 subagent（如 Claude Code Agent 工具），每次一 Phase

set -u

CMD="${1:-detect}"

has_tty() {
  tty -s 2>/dev/null && return 0 || return 1
}

has_codex() {
  command -v codex > /dev/null 2>&1
}

has_tmux() {
  command -v tmux > /dev/null 2>&1 && tmux -V > /dev/null 2>&1
}

is_in_worktree() {
  [[ -d ".git" ]] || git rev-parse --is-inside-work-tree > /dev/null 2>&1
}

# Subagent 探测：识别"Claude / Codex / 其他 LLM agent 派任务给当前进程"的环境
is_in_subagent_capable_env() {
  # Claude Code: 注入 CLAUDECODE=1 + CLAUDE_CODE_ENTRYPOINT
  # 老版本兼容信号: CC_PROJECT / ANTHROPIC_AGENT_RUNTIME
  # Cursor / Aider 等若注入特定 env，可在此扩展
  [[ -n "${CLAUDECODE:-}" ]] && return 0
  [[ -n "${CLAUDE_CODE_ENTRYPOINT:-}" ]] && return 0
  [[ -n "${CC_PROJECT:-}" ]] && return 0
  [[ -n "${ANTHROPIC_AGENT_RUNTIME:-}" ]] && return 0
  return 1
}

detect_mode() {
  if ! has_codex; then
    echo "ERROR: codex not installed" >&2
    return 2
  fi
  if ! is_in_worktree; then
    echo "ERROR: not in a git worktree" >&2
    return 2
  fi
  if has_tty; then
    echo "CLI-YOLO"
    return 0
  fi
  # Claude→Codex 派任务场景 + tmux 可用 → TMUX-YOLO 首选
  # 设 CODEX_GOAL_DISABLE_TMUX_YOLO=1 可强制走旧逻辑（用于 caller 还没升级到识别 TMUX-YOLO 时）
  if [[ -z "${CODEX_GOAL_DISABLE_TMUX_YOLO:-}" ]] && is_in_subagent_capable_env && has_tmux; then
    echo "TMUX-YOLO"
    return 0
  fi
  if is_in_subagent_capable_env; then
    echo "SUBAGENT"
  else
    echo "CLI-EXEC"
  fi
}

print_capabilities() {
  local tty_ok="false"; has_tty && tty_ok="true"
  local codex_ok="false"; has_codex && codex_ok="true"
  local tmux_ok="false"; has_tmux && tmux_ok="true"
  local worktree_ok="false"; is_in_worktree && worktree_ok="true"
  local subagent_hint="false"; is_in_subagent_capable_env && subagent_hint="true"
  local codex_version=""; has_codex && codex_version=$(codex --version 2>/dev/null | head -1)
  local tmux_version=""; has_tmux && tmux_version=$(tmux -V 2>/dev/null)

  # 推荐字段：Claude→Codex 派任务场景（无 TTY + subagent env）+ tmux 可用 → 强烈建议 TMUX-YOLO
  local recommend="none"
  if ! has_tty && is_in_subagent_capable_env && has_tmux && has_codex && is_in_worktree; then
    recommend="TMUX-YOLO"
  fi

  cat <<EOF
{
  "tty": $tty_ok,
  "codex_installed": $codex_ok,
  "codex_version": "$codex_version",
  "tmux_installed": $tmux_ok,
  "tmux_version": "$tmux_version",
  "in_worktree": $worktree_ok,
  "subagent_env_hint": $subagent_hint,
  "shell": "$SHELL",
  "uname": "$(uname -s)",
  "recommend": "$recommend"
}
EOF
}

case "$CMD" in
  detect)       detect_mode ;;
  capabilities) print_capabilities ;;
  *)            echo "Usage: $0 detect|capabilities" >&2; exit 1 ;;
esac
