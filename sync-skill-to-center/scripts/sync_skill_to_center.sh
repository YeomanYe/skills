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
SKILLSHARE_DEST="$SKILLSHARE_ROOT/$SKILL_NAME"
OVERWROTE=0

path_with_home_var() {
  local p="$1"
  case "$p" in
    "$HOME"/*) printf '${HOME}%s\n' "${p#"$HOME"}" ;;
    *) printf '%s\n' "$p" ;;
  esac
}

mkdir -p "$SKILLSHARE_ROOT"

if [[ -e "$SKILLSHARE_DEST" ]]; then
  OVERWROTE=1
fi

rm -rf "$SKILLSHARE_DEST"
cp -R "$SOURCE_DIR" "$SKILLSHARE_DEST"

SOURCE_PATH_FMT="$(path_with_home_var "$SOURCE_DIR")"
DEST_PATH_FMT="$(path_with_home_var "$SKILLSHARE_DEST")"

printf 'source=%s\n' "$SOURCE_PATH_FMT"
printf 'destination=["%s"]\n' "$DEST_PATH_FMT"
printf 'overwrote=%s\n' "$OVERWROTE"
