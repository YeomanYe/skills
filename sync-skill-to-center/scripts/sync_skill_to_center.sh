#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "usage: sync_skill_to_center.sh [source-dir]" >&2
  exit 2
fi

SOURCE_INPUT="${1:-.}"

if ! SOURCE_DIR="$(cd "$SOURCE_INPUT" 2>/dev/null && pwd)"; then
  echo "source directory not found: $SOURCE_INPUT" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_DIR/SKILL.md" ]]; then
  echo "SKILL.md not found in source directory: $SOURCE_DIR" >&2
  exit 1
fi

SKILL_NAME="$(basename "$SOURCE_DIR")"
SKILLSHARE_ROOT="$HOME/.config/skillshare/skills"
OVERWROTE=0

path_with_home_var() {
  local p="$1"
  case "$p" in
    "$HOME"/*) printf '${HOME}%s\n' "${p#"$HOME"}" ;;
    *) printf '%s\n' "$p" ;;
  esac
}

mkdir -p "$SKILLSHARE_ROOT"

declare -a TARGET_ROOTS=("$SKILLSHARE_ROOT")
declare -a CANDIDATE_ROOTS=(
  "$HOME/.agents/skills"
  "$HOME/.claude/skills"
  "$HOME/.cursor/skills"
  "$HOME/.windsurf/skills"
  "$HOME/.opencode/skills"
)

for root in "${CANDIDATE_ROOTS[@]}"; do
  if [[ -d "$root" ]]; then
    TARGET_ROOTS+=("$root")
  fi
done

declare -a UNIQUE_TARGET_ROOTS=()

for root in "${TARGET_ROOTS[@]}"; do
  already_seen=0
  if [[ "${#UNIQUE_TARGET_ROOTS[@]}" -gt 0 ]]; then
    for seen_root in "${UNIQUE_TARGET_ROOTS[@]}"; do
      if [[ "$seen_root" == "$root" ]]; then
        already_seen=1
        break
      fi
    done
  fi
  if [[ "$already_seen" -eq 0 ]]; then
    UNIQUE_TARGET_ROOTS+=("$root")
  fi
done

declare -a DEST_PATHS_FMT=()

for root in "${UNIQUE_TARGET_ROOTS[@]}"; do
  mkdir -p "$root"
  dest="$root/$SKILL_NAME"

  if [[ "$dest" == "$SOURCE_DIR" ]]; then
    DEST_PATHS_FMT+=("$(path_with_home_var "$dest")")
    continue
  fi

  if [[ -e "$dest" ]]; then
    OVERWROTE=1
  fi

  rm -rf "$dest"
  cp -R "$SOURCE_DIR" "$dest"
  DEST_PATHS_FMT+=("$(path_with_home_var "$dest")")
done

SOURCE_PATH_FMT="$(path_with_home_var "$SOURCE_DIR")"

# --- IM-origin auto commit & push ---------------------------------------
# Trigger: CC_SESSION_KEY starts with "feishu:" (a Feishu-origin cc-connect
# session). Other IM platforms are left untouched per user request. The
# skillshare skills dir is expected to be a git repo with a remote configured.
#
# Env overrides:
#   NICHE_AUTOSYNC_GIT=0     → disable entirely
#   NICHE_AUTOSYNC_GIT=1     → force on regardless of CC_SESSION_KEY
GIT_STATUS="skipped"
GIT_REASON=""
GIT_COMMIT=""

should_git=0
if [[ "${NICHE_AUTOSYNC_GIT:-}" == "0" ]]; then
  GIT_REASON="disabled via NICHE_AUTOSYNC_GIT=0"
elif [[ "${NICHE_AUTOSYNC_GIT:-}" == "1" ]]; then
  should_git=1
elif [[ "${CC_SESSION_KEY:-}" == feishu:* ]]; then
  should_git=1
else
  GIT_REASON="non-feishu session (CC_SESSION_KEY=${CC_SESSION_KEY:-unset})"
fi

if [[ "$should_git" -eq 1 ]]; then
  if ! command -v git >/dev/null 2>&1; then
    GIT_STATUS="failed"
    GIT_REASON="git not found in PATH"
  elif [[ ! -d "$SKILLSHARE_ROOT/.git" ]]; then
    GIT_STATUS="failed"
    GIT_REASON="skillshare root is not a git repository: $SKILLSHARE_ROOT"
  else
    pushd "$SKILLSHARE_ROOT" >/dev/null
    git add -- "$SKILL_NAME" >/dev/null 2>&1 || true
    if git diff --cached --quiet -- "$SKILL_NAME"; then
      GIT_STATUS="no-op"
      GIT_REASON="no changes to commit"
    else
      platform="${CC_SESSION_KEY%%:*}"
      platform="${platform:-im}"
      commit_msg="feat($SKILL_NAME): sync from $platform session"
      if git commit -m "$commit_msg" >/dev/null 2>&1; then
        GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo '')"
        if git push >/dev/null 2>&1; then
          GIT_STATUS="pushed"
        else
          GIT_STATUS="committed"
          GIT_REASON="git push failed (check remote/credentials)"
        fi
      else
        GIT_STATUS="failed"
        GIT_REASON="git commit failed"
      fi
    fi
    popd >/dev/null
  fi
fi
# ------------------------------------------------------------------------

printf 'source=%s\n' "$SOURCE_PATH_FMT"
printf 'destination=['
for idx in "${!DEST_PATHS_FMT[@]}"; do
  if [[ "$idx" -gt 0 ]]; then
    printf ','
  fi
  printf '"%s"' "${DEST_PATHS_FMT[$idx]}"
done
printf ']\n'
printf 'overwrote=%s\n' "$OVERWROTE"
printf 'git_status=%s\n' "$GIT_STATUS"
if [[ -n "$GIT_COMMIT" ]]; then
  printf 'git_commit=%s\n' "$GIT_COMMIT"
fi
if [[ -n "$GIT_REASON" ]]; then
  printf 'git_reason=%s\n' "$GIT_REASON"
fi
