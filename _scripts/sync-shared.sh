#!/usr/bin/env bash
# sync-shared.sh — 把 _shared/ 中的共享 reference 复制到所有引用 skill 的 references/
#
# 为什么需要：
#   skillshare sync 只同步含 SKILL.md 的目录到目标（如 ~/.claude/skills/）。
#   _shared/ 不是 skill，不会被同步过去。
#   agent 运行时如果 SKILL.md 引用 `_shared/X.md`，会找不到文件。
#   解决：把 _shared/X.md 复制到每个引用 skill 的 references/X.md
#   （SKILL.md 引用改成 `references/X.md`，同级相对路径 skillshare 同步后仍可达）。
#
# 用法:
#   bash _scripts/sync-shared.sh        # 同步并报告差异
#   bash _scripts/sync-shared.sh --check # 仅检查（exit 1 if 任一副本过时）

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SHARED="$ROOT/_shared"

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

# 映射表：_shared 文件 → 哪些 skill 的 references/ 需要它
declare -a SHARED_FILES=(
  "parallelization-template.md"
  "handoff-payload-template.md"
  "director-template.md"
  "evidence-discovery.md"
  "question-gate.md"
  "constitution.md"
  "audit-rubric.md"
  "output-contract-schema.md"
  "dispatcher-template.md"
)

# 各 _shared 文件的目标 skill（基于 grep 实际引用）
parallelization_target_skills=(
  flow-dev-task
  flow-project-finish
  flow-ext-publish
  flow-project-bootstrap
  flow-codex-goal
  director-design
  director-frontend
  director-promote
  director-ops
  director-architect
)

handoff_payload_target_skills=(
  flow-codex-goal
  director-design
  director-frontend
  director-promote
  director-ops
  director-architect
)

# director-* 元规范、证据查找、Question Gate 三个共享给所有 4 个 director-*
director_template_target_skills=(
  director-design
  director-frontend
  director-promote
  director-ops
  director-architect
)

evidence_discovery_target_skills=(
  director-design
  director-frontend
  director-promote
  director-ops
  director-architect
)

question_gate_target_skills=(
  director-design
  director-frontend
  director-promote
  director-ops
  director-architect
)

# constitution.md 给所有 director-* + flow-* + experience-summary + hat + unblock-recipes + mem (16 skill 顶层契约)
constitution_target_skills=(
  director-design
  director-frontend
  director-promote
  director-ops
  director-architect
  flow-codex-goal
  flow-dev-task
  flow-ext-publish
  flow-project-bootstrap
  flow-project-finish
  flow-skill-dev
  flow-skill-research
  experience-summary
  hat
  unblock-recipes
  change-recap
  mem
)

# audit-rubric.md 给 5 director-* + experience-summary (7 维质量评分共用)
audit_rubric_target_skills=(
  director-design
  director-frontend
  director-promote
  director-ops
  director-architect
  experience-summary
)

# output-contract-schema.md 给所有输出报告类 skill (16 个,含 director-* / flow-* / 单体 skill)
output_contract_schema_target_skills=(
  director-design
  director-frontend
  director-promote
  director-ops
  director-architect
  flow-dev-task
  flow-codex-goal
  flow-project-finish
  flow-project-bootstrap
  flow-ext-publish
  flow-skill-dev
  flow-skill-research
  experience-summary
  change-recap
  hat
  todo-flow
)

# dispatcher-template.md 给所有 orchestrator / dispatcher 类 skill (15 个)
dispatcher_template_target_skills=(
  flow-codex-goal
  flow-dev-task
  flow-project-finish
  flow-project-bootstrap
  flow-ext-publish
  flow-skill-dev
  flow-skill-research
  todo-flow
  director-design
  director-frontend
  director-promote
  director-ops
  director-architect
  experience-summary
  change-recap
)

drift_count=0

sync_one() {
  local src_file="$1"
  shift
  local targets=("$@")

  local src="$SHARED/$src_file"
  [[ -f "$src" ]] || { echo "ERR: $src 不存在"; return 1; }

  local src_sha
  src_sha=$(shasum -a 256 "$src" | awk '{print $1}')

  for skill in "${targets[@]}"; do
    local dst_dir="$ROOT/$skill/references"
    local dst="$dst_dir/$src_file"

    mkdir -p "$dst_dir"

    if [[ -f "$dst" ]]; then
      local dst_sha
      dst_sha=$(shasum -a 256 "$dst" | awk '{print $1}')
      if [[ "$src_sha" == "$dst_sha" ]]; then
        echo "  ✓ $skill/references/$src_file (up-to-date)"
        continue
      else
        drift_count=$((drift_count + 1))
        if [[ $CHECK_ONLY -eq 1 ]]; then
          echo "  ✗ $skill/references/$src_file DRIFT (src=$src_sha != dst=$dst_sha)"
        else
          cp "$src" "$dst"
          echo "  ↻ $skill/references/$src_file synced"
        fi
      fi
    else
      drift_count=$((drift_count + 1))
      if [[ $CHECK_ONLY -eq 1 ]]; then
        echo "  ✗ $skill/references/$src_file MISSING"
      else
        cp "$src" "$dst"
        echo "  + $skill/references/$src_file created"
      fi
    fi
  done
}

echo "Syncing _shared/ → */references/ ..."
echo ""

echo "[parallelization-template.md]"
sync_one "parallelization-template.md" "${parallelization_target_skills[@]}"
echo ""

echo "[handoff-payload-template.md]"
sync_one "handoff-payload-template.md" "${handoff_payload_target_skills[@]}"
echo ""

echo "[director-template.md]"
sync_one "director-template.md" "${director_template_target_skills[@]}"
echo ""

echo "[evidence-discovery.md]"
sync_one "evidence-discovery.md" "${evidence_discovery_target_skills[@]}"
echo ""

echo "[question-gate.md]"
sync_one "question-gate.md" "${question_gate_target_skills[@]}"
echo ""

echo "[constitution.md]"
sync_one "constitution.md" "${constitution_target_skills[@]}"
echo ""

echo "[audit-rubric.md]"
sync_one "audit-rubric.md" "${audit_rubric_target_skills[@]}"
echo ""

echo "[output-contract-schema.md]"
sync_one "output-contract-schema.md" "${output_contract_schema_target_skills[@]}"
echo ""

echo "[dispatcher-template.md]"
sync_one "dispatcher-template.md" "${dispatcher_template_target_skills[@]}"
echo ""

if [[ $CHECK_ONLY -eq 1 ]]; then
  if [[ $drift_count -gt 0 ]]; then
    echo "FAIL: $drift_count file(s) drift; run 'bash _scripts/sync-shared.sh' to fix"
    exit 1
  else
    echo "OK: all _shared/ files in sync"
    exit 0
  fi
else
  echo "Sync done. ($drift_count file(s) updated in source repo)"
  if [[ $drift_count -gt 0 ]]; then
    echo ""
    echo "⚠️  下一步必须把改动推到目标环境（agent 实际读 skill 的位置）："
    echo "    1. git add -A && git commit && git push origin main   # 推到 GitHub"
    echo "    2. cd ~/.config/skillshare/skills && git pull origin main  # skillshare source 拉更新"
    echo "    3. skillshare sync --force                              # 同步到 ~/.claude/skills/ 等"
    echo ""
    echo "    禁止用 rsync 把开发位置硬覆盖到 ~/.config/skillshare/skills/"
    echo "    （那会污染 skillshare 的 git clone 状态，绕过 GitHub 单一事实源）"
  fi
fi
