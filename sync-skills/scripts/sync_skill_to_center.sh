#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "usage: sync_skill_to_center.sh [source-dir]" >&2
  exit 2
fi

SOURCE_INPUT="${1:-.}"

if ! SOURCE_DIR="$(cd "$SOURCE_INPUT" 2>/dev/null && pwd -P)"; then
  echo "source directory not found: $SOURCE_INPUT" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_DIR/SKILL.md" ]]; then
  echo "SKILL.md not found in source directory: $SOURCE_DIR" >&2
  exit 1
fi

SKILL_NAME="$(basename "$SOURCE_DIR")"

# Plugin prefix stripping: when the source lives under an AI tool's sync target
# (e.g. ~/.claude/skills/_YeomanYe-skills__foo), basename gives the prefixed
# name and syncing that to center would create a wrong directory. Detect the
# sync-target paths and strip the prefix automatically. DEST_NAME env var
# overrides (skips the auto logic entirely).
if [[ "${DEST_NAME:-}" == "" ]]; then
  case "$SOURCE_DIR" in
    "$HOME"/.claude/skills/*|"$HOME"/.agents/skills/*|"$HOME"/.codex/skills/*)
      if [[ "$SKILL_NAME" =~ ^_[a-zA-Z0-9-]+__(skills__)?(.+)$ ]]; then
        naked="${BASH_REMATCH[2]}"
        echo "note: source is under AI tool sync target; stripping plugin prefix '$SKILL_NAME' → '$naked'" >&2
        echo "      set DEST_NAME=<name> to override" >&2
        SKILL_NAME="$naked"
      fi
      ;;
  esac
fi

SKILL_NAME="${DEST_NAME:-$SKILL_NAME}"

SKILLS_ROOT="$HOME/Documents/projects/skills"
OVERWROTE=0

path_with_home_var() {
  local p="$1"
  case "$p" in
    "$HOME"/*) printf '${HOME}%s\n' "${p#"$HOME"}" ;;
    *) printf '%s\n' "$p" ;;
  esac
}

# Resolve symlinks and return the physical path. If the path doesn't exist,
# returns empty string (caller should then treat as "new target").
canonicalize() {
  local p="$1"
  if [[ -d "$p" ]]; then
    ( cd "$p" 2>/dev/null && pwd -P ) || return 0
  elif [[ -L "$p" ]]; then
    # Broken or loop symlink: canonicalize via parent.
    local parent
    parent="$(dirname "$p")"
    ( cd "$parent" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$(basename "$p")" ) || return 0
  fi
}

mkdir -p "$SKILLS_ROOT"

dest="$SKILLS_ROOT/$SKILL_NAME"

# Skip when dest and source resolve to the same physical path. This covers:
#   - dest == source (literal equality)
#   - dest is a symlink pointing to source (or vice-versa)
# Without this, `rm -rf dest` destroys the real skill dir and `cp -R`
# produces a self-referencing symlink loop.
self_reference=0
dest_canon="$(canonicalize "$dest" 2>/dev/null || true)"
if [[ -n "$dest_canon" && "$dest_canon" == "$SOURCE_DIR" ]]; then
  self_reference=1
fi

# Defense in depth: if dest is a symlink, resolve the link target and bail
# out if it ends up at source.
if [[ "$self_reference" -eq 0 && -L "$dest" ]]; then
  link_target="$(readlink "$dest")"
  case "$link_target" in
    /*) link_abs="$link_target" ;;
    *)  link_abs="$(dirname "$dest")/$link_target" ;;
  esac
  link_canon="$(canonicalize "$link_abs" 2>/dev/null || true)"
  if [[ -n "$link_canon" && "$link_canon" == "$SOURCE_DIR" ]]; then
    self_reference=1
  fi
fi

if [[ "$self_reference" -eq 0 ]]; then
  if [[ -e "$dest" || -L "$dest" ]]; then
    OVERWROTE=1
  fi
  rm -rf "$dest"
  cp -R "$SOURCE_DIR" "$dest"
fi

DEST_PATH_FMT="$(path_with_home_var "$dest")"
SOURCE_PATH_FMT="$(path_with_home_var "$SOURCE_DIR")"

# --- IM-origin auto commit & push ---------------------------------------
# Trigger: CC_SESSION_KEY is non-empty (any IM-origin cc-connect session —
# Feishu / Telegram / Discord / WeChat / QQ, etc.). Local CLI invocations
# (CC_SESSION_KEY unset) are left untouched so the user commits manually.
# Aligns with flow-dev-task / clean-commit (IM session → auto push).
# The skills dir is expected to be a git repo with a remote configured.
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
elif [[ -n "${CC_SESSION_KEY:-}" ]]; then
  should_git=1
else
  GIT_REASON="non-IM session (local CLI, CC_SESSION_KEY unset)"
fi

if [[ "$should_git" -eq 1 ]]; then
  if ! command -v git >/dev/null 2>&1; then
    GIT_STATUS="failed"
    GIT_REASON="git not found in PATH"
  elif [[ ! -d "$SKILLS_ROOT/.git" ]]; then
    GIT_STATUS="failed"
    GIT_REASON="skills root is not a git repository: $SKILLS_ROOT"
  else
    pushd "$SKILLS_ROOT" >/dev/null
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
printf 'destination=["%s"]\n' "$DEST_PATH_FMT"
printf 'effective_skill_name=%s\n' "$SKILL_NAME"
printf 'overwrote=%s\n' "$OVERWROTE"
printf 'git_status=%s\n' "$GIT_STATUS"
if [[ -n "$GIT_COMMIT" ]]; then
  printf 'git_commit=%s\n' "$GIT_COMMIT"
fi
if [[ -n "$GIT_REASON" ]]; then
  printf 'git_reason=%s\n' "$GIT_REASON"
fi
