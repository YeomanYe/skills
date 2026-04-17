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
